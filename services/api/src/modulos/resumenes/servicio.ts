import type { PoolClient } from 'pg';
import { encolar } from '../../cola/encolar.js';
import { ErrorDefinitivo, ErrorReintentable } from '../../cola/errores.js';
import { pool, withTransaction } from '../../db/pool.js';
import { decimal, detalleResumen } from '../../dominio/tributos/index.js';
import { agruparStock, itemsDe, moverStock } from '../comprobantes/repositorio.js';
import { codigoLimpio, explicarCodigo, numeroCompleto } from '../../sunat/catalogos.js';
import { extensionCdr } from '../../sunat/cdr.js';
import { clasificarRespuesta, codigoDeRespuesta, decidirTicket, textoDeRespuesta } from '../../sunat/clasificacion.js';
import { ErrorRedSunat, type RespuestaSunat } from '../../sunat/cliente.js';
import { leerConfiguracionSunat, obtenerCredencialesSunat } from '../../sunat/config.js';
import { guardarBase64, leerEmpresa } from '../../sunat/datos.js';
import { emisorDe } from '../../sunat/documento.js';
import { ENVIO_VENCIDO_MS } from '../../sunat/envio.js';
import { llamarGateway } from '../../sunat/gateway.js';

export type ClaseTicket = 'resumen' | 'baja';

const MAXIMO_LINEAS_RESUMEN = 500;
const ESPERA_PRIMERA_CONSULTA_MS = 15_000;
const TIPOS_QUE_REPUSIERON_STOCK = new Set(['01', '03', 'NV']);

const CLASES = {
  resumen: { tabla: 'resumenes_diarios', prefijo: 'RC', ruta: 'resumen' },
  baja: { tabla: 'comunicaciones_baja', prefijo: 'RA', ruta: 'baja' },
} as const;

export interface ItemResumen {
  comprobante_id: string;
  tipo_documento: string;
  serie_numero: string;
  estado: '1' | '3';
  cliente_tipo: string;
  cliente_numero: string;
  total: number;
  mto_oper_gravadas: number;
  mto_oper_exoneradas: number;
  mto_oper_inafectas: number;
  mto_oper_gratuitas: number;
  mto_igv: number;
  mto_isc: number;
  mto_icbper: number;
  documento_referencia: { tipo_documento: string; numero_documento: string } | null;
}

export interface ItemBaja {
  tipo_documento: string;
  serie: string;
  correlativo: string;
  motivo_especifico: string;
}

interface FilaTicket {
  id: string;
  fecha_referencia: string;
  fecha_generacion: string | null;
  correlativo: number | null;
  identificador: string | null;
  estado: string;
  ticket: string | null;
  xml_path: string | null;
  cdr_path: string | null;
  items: (ItemResumen | ItemBaja)[];
  entorno: 'beta' | 'produccion' | null;
  comprobante_id?: string | null;
}

interface ComprobanteResumible {
  id: string;
  tipo: string;
  serie: string;
  correlativo: number;
  fecha_emision: string;
  moneda: string;
  cliente_tipo_documento: string;
  cliente_numero_documento: string | null;
  total: string;
  op_gravadas: string;
  op_exoneradas: string;
  op_inafectas: string;
  op_gratuitas: string;
  igv: string;
  icbper: string;
  afectado_tipo: string | null;
  afectado_serie: string | null;
  afectado_correlativo: number | null;
  entorno: 'beta' | 'produccion' | null;
}

const SELECCION_RESUMIBLE = `id, tipo, serie, correlativo, fecha_emision::text, moneda, cliente_tipo_documento, cliente_numero_documento,
  total::text, op_gravadas::text, op_exoneradas::text, op_inafectas::text, op_gratuitas::text, igv::text, icbper::text,
  afectado_tipo, afectado_serie, afectado_correlativo, entorno`;

export const hoyLima = (ahora = new Date()): string => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Lima' }).format(ahora);

export function minutosLima(ahora = new Date()): number {
  const partes = new Intl.DateTimeFormat('en-GB', { timeZone: 'America/Lima', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(ahora);
  const valor = (tipo: string) => Number(partes.find((p) => p.type === tipo)?.value ?? 0);
  return valor('hour') * 60 + valor('minute');
}

export function itemResumen(c: ComprobanteResumible, estado: '1' | '3'): ItemResumen {
  return { ...detalleResumen(c, estado), comprobante_id: c.id };
}

async function reservarCorrelativo(c: PoolClient, clase: ClaseTicket, fecha: string): Promise<{ correlativo: number; identificador: string }> {
  const { tabla, prefijo } = CLASES[clase];
  await c.query(`select pg_advisory_xact_lock(hashtextextended($1, 0))`, [`${tabla}:${fecha}`]);
  const { rows } = await c.query<{ siguiente: number }>(`select coalesce(max(correlativo), 0) + 1 as siguiente from ${tabla} where fecha_generacion = $1`, [fecha]);
  const correlativo = Number(rows[0].siguiente);
  return { correlativo, identificador: `${prefijo}-${fecha.replace(/-/g, '')}-${String(correlativo).padStart(3, '0')}` };
}

async function crearResumen(c: PoolClient, fechaReferencia: string, items: ItemResumen[], entorno: string): Promise<string> {
  const hoy = hoyLima();
  const { correlativo, identificador } = await reservarCorrelativo(c, 'resumen', hoy);
  const { rows } = await c.query<{ id: string }>(
    `insert into resumenes_diarios (fecha_referencia, fecha_generacion, correlativo, identificador, items, entorno)
     values ($1, $2, $3, $4, $5::jsonb, $6) returning id`,
    [fechaReferencia, hoy, correlativo, identificador, JSON.stringify(items), entorno],
  );
  await encolar(c, 'enviar_resumen', { resumen_id: rows[0].id });
  return rows[0].id;
}

export async function generarResumenDiario(fecha?: string): Promise<string[]> {
  return withTransaction(async (c) => {
    const { entorno } = await leerConfiguracionSunat(c);
    await c.query(`select pg_advisory_xact_lock(hashtext('generar_resumen_diario'))`);
    const filtroFecha = fecha ? 'fecha_emision = $2::date' : 'fecha_emision < $2::date';
    const { rows } = await c.query<ComprobanteResumible>(
      `select ${SELECCION_RESUMIBLE} from comprobantes
        where estado = 'por_resumen' and resumen_id is null and tipo <> 'NV'
          and (entorno is null or entorno = $1) and ${filtroFecha}
        order by fecha_emision, serie, correlativo
        for update`,
      [entorno, fecha ?? hoyLima()],
    );
    const grupos = new Map<string, ComprobanteResumible[]>();
    for (const fila of rows) {
      const clave = `${fila.fecha_emision}|${fila.moneda}`;
      grupos.set(clave, [...(grupos.get(clave) ?? []), fila]);
    }
    const creados: string[] = [];
    for (const [clave, filas] of grupos) {
      const [fechaReferencia] = clave.split('|');
      for (let i = 0; i < filas.length; i += MAXIMO_LINEAS_RESUMEN) {
        const lote = filas.slice(i, i + MAXIMO_LINEAS_RESUMEN);
        const id = await crearResumen(c, fechaReferencia, lote.map((f) => itemResumen(f, '1')), entorno);
        await c.query(`update comprobantes set resumen_id = $1, entorno = $2 where id = any($3::uuid[])`, [id, entorno, lote.map((f) => f.id)]);
        creados.push(id);
      }
    }
    return creados;
  });
}

export async function programarResumenSiCorresponde(ahora = new Date()): Promise<boolean> {
  const MINUTO_RESUMEN = 90;
  if (minutosLima(ahora) < MINUTO_RESUMEN) return false;
  const fecha = hoyLima(ahora);
  return withTransaction(async (c) => {
    await c.query(`select pg_advisory_xact_lock(hashtext('programar_resumen_diario'))`);
    const { rows } = await c.query(`select 1 from trabajos where tipo = 'generar_resumen_diario' and payload->>'programado_para' = $1 limit 1`, [fecha]);
    if (rows.length) return false;
    await encolar(c, 'generar_resumen_diario', { programado_para: fecha });
    return true;
  });
}

async function leerFila(clase: ClaseTicket, id: string): Promise<FilaTicket | null> {
  const { rows } = await pool.query<FilaTicket>(
    `select id, fecha_referencia::text, fecha_generacion::text, correlativo, identificador, estado, ticket, xml_path, cdr_path, items, entorno${clase === 'baja' ? ', comprobante_id' : ''}
       from ${CLASES[clase].tabla} where id = $1`,
    [id],
  );
  return rows[0] ?? null;
}

export async function revertirAnulaciones(c: PoolClient, ids: string[], nota: string): Promise<void> {
  for (const id of ids) {
    const { rows } = await c.query<{ tipo: string; establecimiento_id: string; usuario_id: string }>(
      `select tipo, establecimiento_id, usuario_id from comprobantes where id = $1 and estado = 'por_anular' for update`,
      [id],
    );
    const comprobante = rows[0];
    if (!comprobante) continue;
    await c.query(
      `update comprobantes
          set estado = case when coalesce(sunat_codigo, '0') ~ '^[4-9][0-9]{3}$' then 'observado' else 'aceptado' end,
              sunat_descripcion = $2
        where id = $1`,
      [id, nota],
    );
    if (!TIPOS_QUE_REPUSIERON_STOCK.has(comprobante.tipo)) continue;
    const items = await itemsDe(c, id);
    const productos = [...new Set(items.flatMap((i) => (i.producto_id ? [i.producto_id] : [])))];
    if (!productos.length) continue;
    const controlados = await c.query<{ id: string }>(`select id from productos where id = any($1::uuid[]) and controla_stock`, [productos]);
    const conStock = new Set(controlados.rows.map((p) => p.id));
    const lineas = agruparStock(items.map((i) => ({ producto_id: i.producto_id, controla_stock: Boolean(i.producto_id && conStock.has(i.producto_id)), cantidad: decimal(i.cantidad) })));
    await moverStock(c, lineas, { tipo: 'venta', signo: -1, establecimientoId: comprobante.establecimiento_id, comprobanteId: id, usuarioId: comprobante.usuario_id });
  }
}

const idsPorEstado = (items: ItemResumen[], estado: '1' | '3'): string[] => items.filter((i) => i.estado === estado).map((i) => i.comprobante_id);

async function liberarDocumentos(c: PoolClient, clase: ClaseTicket, fila: FilaTicket, nota: string): Promise<void> {
  if (clase === 'baja') {
    await revertirAnulaciones(c, fila.comprobante_id ? [fila.comprobante_id] : [], `Anulación no aceptada: ${nota}`);
    return;
  }
  const items = fila.items as ItemResumen[];
  await c.query(`update comprobantes set resumen_id = null where resumen_id = $1 and id = any($2::uuid[])`, [fila.id, idsPorEstado(items, '1')]);
  await revertirAnulaciones(c, idsPorEstado(items, '3'), `Anulación no aceptada: ${nota}`);
}

async function cerrarConError(clase: ClaseTicket, fila: FilaTicket, estado: string, codigo: string | null, descripcion: string, xml_path: string | null): Promise<void> {
  await withTransaction(async (c) => {
    await c.query(`update ${CLASES[clase].tabla} set estado = $2, sunat_codigo = $3, sunat_descripcion = $4, xml_path = $5 where id = $1`, [fila.id, estado, codigo, descripcion, xml_path]);
    await liberarDocumentos(c, clase, fila, descripcion);
  });
}

function detallesGateway(clase: ClaseTicket, fila: FilaTicket, porcentajeIgv: number): unknown[] {
  if (clase === 'baja') {
    return (fila.items as ItemBaja[]).map((i) => ({ tipo_documento: i.tipo_documento, serie: i.serie, correlativo: String(Number(i.correlativo)), motivo: i.motivo_especifico }));
  }
  return (fila.items as ItemResumen[]).map((i) => ({
    tipo_documento: i.tipo_documento,
    serie_numero: i.serie_numero,
    estado: i.estado,
    cliente_tipo: i.cliente_tipo,
    cliente_numero: i.cliente_numero,
    total: i.total,
    op_gravadas: i.mto_oper_gravadas,
    op_exoneradas: i.mto_oper_exoneradas,
    op_inafectas: i.mto_oper_inafectas,
    op_gratuitas: i.mto_oper_gratuitas,
    igv: i.mto_igv,
    porcentaje_igv: porcentajeIgv,
    isc: i.mto_isc,
    icbper: i.mto_icbper,
    documento_referencia: i.documento_referencia,
  }));
}

async function porcentajeIgvEmpresa(): Promise<number> {
  const { rows } = await pool.query<{ igv_porcentaje: string }>(`select igv_porcentaje from empresa where id = 1`);
  return Number(rows[0].igv_porcentaje);
}

async function monedaDelResumen(fila: FilaTicket): Promise<string> {
  const { rows } = await pool.query<{ moneda: string }>(`select moneda from comprobantes where id = $1`, [(fila.items[0] as ItemResumen).comprobante_id]);
  return rows[0]?.moneda ?? 'PEN';
}

async function renumerarSiCambioElDia(clase: ClaseTicket, fila: FilaTicket): Promise<FilaTicket> {
  const hoy = hoyLima();
  if (fila.fecha_generacion === hoy) return fila;
  return withTransaction(async (c) => {
    const { correlativo, identificador } = await reservarCorrelativo(c, clase, hoy);
    await c.query(`update ${CLASES[clase].tabla} set correlativo = $2, identificador = $3, fecha_generacion = $4 where id = $1`, [fila.id, correlativo, identificador, hoy]);
    return { ...fila, correlativo, identificador, fecha_generacion: hoy };
  });
}

async function reclamar(clase: ClaseTicket, id: string): Promise<boolean> {
  const { rowCount } = await pool.query(
    `update ${CLASES[clase].tabla} set estado = 'enviando'
      where id = $1 and ticket is null
        and (estado in ('pendiente', 'error')
             or (estado = 'enviando' and actualizado_en < now() - ($2::double precision * interval '1 millisecond')))`,
    [id, ENVIO_VENCIDO_MS],
  );
  return rowCount === 1;
}

async function encolarConsulta(clase: ClaseTicket, id: string, demoraMs: number): Promise<void> {
  await withTransaction((c) => encolar(c, 'consultar_ticket', { clase, id }, new Date(Date.now() + demoraMs)));
}

const FINALES = new Set(['aceptado', 'observado', 'rechazado']);

export async function enviarDocumentoTicket(clase: ClaseTicket, id: string): Promise<void> {
  const inicial = await leerFila(clase, id);
  if (!inicial || FINALES.has(inicial.estado)) return;
  if (inicial.ticket && inicial.estado === 'procesando') {
    await encolarConsulta(clase, id, 0);
    return;
  }
  const [empresa, configuracion] = await Promise.all([leerEmpresa(), leerConfiguracionSunat(pool)]);
  if (inicial.entorno && inicial.entorno !== configuracion.entorno) {
    await cerrarConError(clase, inicial, 'error', null, `Generado en ${inicial.entorno} y el sistema está en ${configuracion.entorno}: no se envía.`, inicial.xml_path);
    return;
  }
  if (!(await reclamar(clase, id))) throw new ErrorReintentable(`${inicial.identificador} ya se está enviando`);

  const fila = await renumerarSiCambioElDia(clase, inicial);
  const { tabla, ruta } = CLASES[clase];
  const liberar = async (mensaje: string) => {
    await pool.query(`update ${tabla} set estado = 'pendiente', sunat_descripcion = $2 where id = $1 and estado = 'enviando'`, [id, `${mensaje}. Se reintentará automáticamente.`]);
  };

  let r: RespuestaSunat;
  try {
    const credenciales = await obtenerCredencialesSunat(pool);
    const correlativo = String(fila.correlativo).padStart(3, '0');
    const base = { correlativo, fecha_referencia: fila.fecha_referencia, fecha_envio: fila.fecha_generacion, detalles: detallesGateway(clase, fila, await porcentajeIgvEmpresa()) };
    const documento = clase === 'resumen' ? { ...base, moneda: await monedaDelResumen(fila) } : base;
    r = await llamarGateway(ruta, { credenciales, emisor: emisorDe(empresa), documento });
    if (clasificarRespuesta(r).tipo === 'reintentar' && !r.ticket) throw new ErrorRedSunat(`SUNAT respondió ${codigoDeRespuesta(r)}`);
  } catch (e) {
    const mensaje = e instanceof Error ? e.message : String(e);
    if (e instanceof ErrorDefinitivo) {
      await cerrarConError(clase, fila, 'error', null, mensaje, fila.xml_path);
      return;
    }
    await liberar(mensaje);
    throw e instanceof ErrorReintentable ? e : new ErrorRedSunat(mensaje);
  }

  const xml_path = r.xml ? await guardarBase64(`${configuracion.entorno}/${empresa.ruc}/${empresa.ruc}-${fila.identificador}.xml`, r.xml, 'application/xml').catch(() => fila.xml_path) : fila.xml_path;
  if (r.exito && r.ticket) {
    await pool.query(`update ${tabla} set estado = 'procesando', ticket = $2, xml_path = $3, entorno = $4, sunat_descripcion = null where id = $1`, [id, r.ticket, xml_path, configuracion.entorno]);
    await encolarConsulta(clase, id, ESPERA_PRIMERA_CONSULTA_MS);
    return;
  }
  const decision = clasificarRespuesta(r);
  const estado = decision.tipo === 'final' && decision.estado === 'rechazado' ? 'rechazado' : 'error';
  const codigo = codigoDeRespuesta(r);
  await cerrarConError(clase, fila, estado, codigo, [textoDeRespuesta(r), explicarCodigo(codigo)].filter(Boolean).join('. '), xml_path);
}

export async function consultarTicket(clase: ClaseTicket, id: string): Promise<void> {
  const fila = await leerFila(clase, id);
  if (!fila?.ticket || fila.estado !== 'procesando') return;
  const [empresa, credenciales] = await Promise.all([leerEmpresa(), obtenerCredencialesSunat(pool)]);
  const r = await llamarGateway('ticket', { credenciales, emisor: emisorDe(empresa), documento: { ticket: fila.ticket } });
  const decision = decidirTicket(r);
  if (decision.tipo === 'en_proceso') throw new ErrorReintentable('SUNAT aún procesa el ticket');
  if (decision.tipo === 'reintentar') throw new ErrorRedSunat(`SUNAT respondió ${codigoDeRespuesta(r)} al consultar el ticket`);

  const entorno = fila.entorno ?? credenciales.entorno.toLowerCase();
  const extension = r.cdr ? extensionCdr(r.cdr) : 'zip';
  const cdr_path = r.cdr
    ? await guardarBase64(`${entorno}/${empresa.ruc}/R-${empresa.ruc}-${fila.identificador}.${extension}`, r.cdr, extension === 'zip' ? 'application/zip' : 'application/xml').catch(() => fila.cdr_path)
    : fila.cdr_path;
  const codigo = codigoLimpio(r.codigo ?? r.error?.codigo);
  const descripcion = [textoDeRespuesta(r), decision.estado === 'aceptado' || decision.estado === 'observado' ? null : explicarCodigo(codigo)].filter(Boolean).join('. ');
  const aceptado = decision.estado === 'aceptado' || decision.estado === 'observado';

  await withTransaction(async (c) => {
    await c.query(`update ${CLASES[clase].tabla} set estado = $2, sunat_codigo = $3, sunat_descripcion = $4, cdr_path = $5 where id = $1`, [id, decision.estado, codigo, descripcion, cdr_path]);
    if (!aceptado) {
      await liberarDocumentos(c, clase, fila, descripcion || 'SUNAT no aceptó el documento');
      return;
    }
    if (clase === 'baja') {
      await c.query(`update comprobantes set estado = 'anulado' where id = any($1::uuid[]) and estado = 'por_anular'`, [fila.comprobante_id ? [fila.comprobante_id] : []]);
      return;
    }
    const items = fila.items as ItemResumen[];
    await c.query(`update comprobantes set estado = 'anulado' where id = any($1::uuid[]) and estado = 'por_anular'`, [idsPorEstado(items, '3')]);
    await c.query(
      `update comprobantes set estado = $2, sunat_codigo = $3, sunat_descripcion = $4, cdr_path = $5, sunat_notas = $6::jsonb
        where id = any($1::uuid[]) and estado = 'por_resumen'`,
      [idsPorEstado(items, '1'), decision.estado, codigo, descripcion, cdr_path, JSON.stringify(r.notas ?? [])],
    );
  });
}

export async function marcarFalloDocumento(clase: ClaseTicket, id: string, detalle: string): Promise<void> {
  const fila = await leerFila(clase, id);
  if (!fila || !['pendiente', 'enviando'].includes(fila.estado)) return;
  await cerrarConError(clase, fila, 'error', null, `${detalle}. Se agotaron los reintentos.`, fila.xml_path);
}

export async function reencolarTicketsPendientes(): Promise<number> {
  let total = 0;
  for (const clase of ['resumen', 'baja'] as const) {
    const { rows } = await pool.query<{ id: string }>(
      `select d.id from ${CLASES[clase].tabla} d
        where d.estado = 'procesando' and d.ticket is not null
          and not exists (select 1 from trabajos t where t.tipo = 'consultar_ticket' and t.estado in ('pendiente', 'procesando') and t.payload->>'id' = d.id::text)`,
    );
    for (const { id } of rows) {
      await encolarConsulta(clase, id, 0);
      total++;
    }
  }
  return total;
}

export async function encolarFirmasPendientes(): Promise<number> {
  return withTransaction(async (c) => {
    const { rows } = await c.query<{ id: string }>(
      `select d.id from comprobantes d
        where d.estado = 'por_resumen' and d.hash is null and d.resumen_id is null
          and not exists (select 1 from trabajos t where t.tipo = 'enviar_comprobante' and t.payload->>'comprobante_id' = d.id::text)
        limit 200`,
    );
    for (const { id } of rows) await encolar(c, 'enviar_comprobante', { comprobante_id: id });
    return rows.length;
  });
}
