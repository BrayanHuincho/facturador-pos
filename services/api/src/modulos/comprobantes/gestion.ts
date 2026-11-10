import type { PoolClient } from 'pg';
import { encolar } from '../../cola/encolar.js';
import { entorno } from '../../config/entorno.js';
import { registrarAuditoria } from '../../db/auditoria.js';
import { withTransaction } from '../../db/pool.js';
import { ErrorApi } from '../../http/errores.js';
import type { UsuarioAutenticado } from '../../http/auth.js';
import { generarPdfComprobante } from '../../pdf/generar.js';
import { subirDocumento, urlFirmada } from '../../storage/archivos.js';
import { obtenerCredencialesSunat } from '../../sunat/config.js';
import { claseDeAnulacion, decimal, detalleBaja, detalleResumen, estadoPorCodigo } from '../../dominio/tributos/index.js';
import { agruparStock, bloquearComprobante, cargarEmpresa, comprobanteCompleto, hoyEnLima, insertarFila, itemsDe, moverStock, type ComprobanteFila } from './repositorio.js';

const noEncontrado = () => new ErrorApi(404, 'COMPROBANTE_NO_ENCONTRADO', 'Comprobante no encontrado.');

function asegurarAcceso(usuario: UsuarioAutenticado, comprobante: { usuario_id: string } | null): asserts comprobante {
  if (!comprobante || (usuario.rol === 'cajero' && comprobante.usuario_id !== usuario.id)) throw noEncontrado();
}

export async function obtener(usuario: UsuarioAutenticado, id: string) {
  return withTransaction(async (c) => {
    const comprobante = await comprobanteCompleto(c, id);
    asegurarAcceso(usuario, comprobante);
    return comprobante;
  });
}

export async function reenviar(usuario: UsuarioAutenticado, id: string) {
  return withTransaction(async (c) => {
    const comprobante = await bloquearComprobante(c, id);
    asegurarAcceso(usuario, comprobante);
    if (comprobante.tipo === 'NV') throw new ErrorApi(409, 'NO_APLICA', 'La nota de venta no se envía a SUNAT.');
    if (['aceptado', 'observado', 'anulado', 'por_anular'].includes(comprobante.estado)) throw new ErrorApi(409, 'YA_INFORMADO', 'SUNAT ya tiene este comprobante.');
    if (comprobante.estado === 'rechazado') throw new ErrorApi(422, 'RECHAZADO_NO_SE_REENVIA', 'SUNAT rechazó este comprobante: reenviarlo daría el mismo rechazo. Anúlalo y emite uno nuevo.');
    if (comprobante.estado === 'por_resumen' || comprobante.resumen_id) throw new ErrorApi(409, 'EN_RESUMEN', 'Este comprobante va en un resumen diario.');
    const activo = await c.query(`SELECT 1 FROM trabajos WHERE tipo = 'enviar_comprobante' AND estado IN ('pendiente', 'procesando') AND payload->>'comprobante_id' = $1 LIMIT 1`, [id]);
    await c.query(`UPDATE comprobantes SET estado = 'pendiente', intentos = 0, actualizado_en = now() WHERE id = $1`, [id]);
    if (!activo.rowCount) await encolar(c, 'enviar_comprobante', { comprobante_id: id });
    return { id, estado: 'pendiente' };
  });
}

interface RespuestaConsulta {
  exito?: boolean;
  codigo?: string | null;
  descripcion?: string | null;
  cdr?: string | null;
  cdr_codigo?: string | number | null;
  cdr_descripcion?: string | null;
  notas?: string[];
  error?: { codigo?: string; mensaje?: string } | null;
}

async function llamarConsultaCpe(cuerpo: unknown): Promise<RespuestaConsulta> {
  let respuesta: Response;
  try {
    respuesta = await fetch(`${entorno.SUNAT_GATEWAY_URL.replace(/\/$/, '')}/consulta-cpe`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Token-Interno': entorno.SUNAT_GATEWAY_TOKEN },
      body: JSON.stringify(cuerpo),
      signal: AbortSignal.timeout(60_000),
    });
  } catch {
    throw new ErrorApi(502, 'SUNAT_NO_RESPONDE', 'El servicio SUNAT no está disponible.');
  }
  return (await respuesta.json().catch(() => ({ exito: false }))) as RespuestaConsulta;
}

export async function consultar(usuario: UsuarioAutenticado, id: string) {
  const preparado = await withTransaction(async (c) => {
    const comprobante = await comprobanteCompleto(c, id);
    asegurarAcceso(usuario, comprobante);
    if (comprobante.tipo === 'NV') throw new ErrorApi(409, 'NO_APLICA', 'La nota de venta no se consulta en SUNAT.');
    const empresa = await cargarEmpresa(c);
    if (empresa.entorno !== 'produccion') throw new ErrorApi(422, 'SOLO_PRODUCCION', 'La consulta de comprobantes solo existe en producción. En pruebas, usa «Reenviar».');
    const establecimiento = await c.query<{ codigo: string }>('SELECT codigo FROM establecimientos WHERE id = $1', [comprobante.establecimiento_id]);
    return { comprobante, empresa, credenciales: await obtenerCredencialesSunat(c), codLocal: establecimiento.rows[0]?.codigo ?? '0000' };
  });
  const { comprobante, empresa, credenciales, codLocal } = preparado;
  const respuesta = await llamarConsultaCpe({
    credenciales,
    emisor: {
      ruc: empresa.ruc,
      razon_social: empresa.razon_social,
      nombre_comercial: empresa.nombre_comercial,
      direccion: empresa.direccion,
      ubigeo: empresa.ubigeo,
      departamento: empresa.departamento,
      provincia: empresa.provincia,
      distrito: empresa.distrito,
      cod_local: codLocal,
    },
    documento: { tipo_documento: comprobante.tipo, serie: comprobante.serie, correlativo: comprobante.correlativo, con_cdr: true },
  });

  if (!respuesta.cdr) return { codigo: respuesta.codigo ?? respuesta.error?.codigo ?? null, descripcion: respuesta.descripcion ?? respuesta.error?.mensaje ?? null, estado: comprobante.estado };

  const ruta = `${comprobante.entorno}/${empresa.ruc}/R-${empresa.ruc}-${comprobante.tipo}-${comprobante.serie}-${comprobante.correlativo}.zip`;
  await subirDocumento(ruta, Buffer.from(respuesta.cdr, 'base64'), 'application/zip');
  const codigoCdr = respuesta.cdr_codigo === null || respuesta.cdr_codigo === undefined ? '0' : String(respuesta.cdr_codigo);
  const estado = await withTransaction(async (c) => {
    const actual = await bloquearComprobante(c, id);
    if (!actual) throw noEncontrado();
    const conservaEstado = ['aceptado', 'observado', 'anulado', 'por_anular'].includes(actual.estado) && Boolean(actual.cdr_path);
    const nuevo = conservaEstado ? actual.estado : estadoPorCodigo(codigoCdr, true);
    await c.query(
      `UPDATE comprobantes SET estado = $2, cdr_path = $3, sunat_codigo = $4, sunat_descripcion = $5, sunat_notas = $6::jsonb, actualizado_en = now() WHERE id = $1`,
      [id, nuevo, ruta, codigoCdr, respuesta.cdr_descripcion ?? respuesta.descripcion ?? null, JSON.stringify(respuesta.notas ?? [])],
    );
    return nuevo;
  });
  return { codigo: respuesta.codigo ?? null, descripcion: respuesta.cdr_descripcion ?? respuesta.descripcion ?? null, estado };
}

async function siguienteCorrelativo(c: PoolClient, tabla: 'resumenes_diarios' | 'comunicaciones_baja', hoy: string): Promise<number> {
  await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [`${tabla}:${hoy}`]);
  const { rows } = await c.query<{ siguiente: number }>(`SELECT COALESCE(MAX(correlativo), 0) + 1 AS siguiente FROM ${tabla} WHERE fecha_generacion = $1`, [hoy]);
  return rows[0]!.siguiente;
}

async function reponerStock(c: PoolClient, comprobante: ComprobanteFila, usuarioId: string): Promise<void> {
  if (!['01', '03', 'NV'].includes(comprobante.tipo)) return;
  const items = await itemsDe(c, comprobante.id);
  const ids = [...new Set(items.flatMap((item) => (item.producto_id ? [item.producto_id] : [])))];
  if (!ids.length) return;
  const { rows } = await c.query<{ id: string }>('SELECT id FROM productos WHERE id = ANY($1::uuid[]) AND controla_stock', [ids]);
  const controlados = new Set(rows.map((fila) => fila.id));
  const lineas = agruparStock(items.map((item) => ({ producto_id: item.producto_id, controla_stock: Boolean(item.producto_id && controlados.has(item.producto_id)), cantidad: decimal(item.cantidad) })));
  await moverStock(c, lineas, { tipo: 'anulacion', signo: 1, establecimientoId: comprobante.establecimiento_id, comprobanteId: comprobante.id, usuarioId });
}

export async function anular(usuario: UsuarioAutenticado, id: string, motivo: string) {
  return withTransaction(async (c) => {
    const comprobante = await bloquearComprobante(c, id);
    if (!comprobante) throw noEncontrado();
    const hoy = hoyEnLima();
    const clase = claseDeAnulacion(comprobante, hoy);
    let documentoId: string | null = null;

    if (clase === 'local') {
      await c.query(`UPDATE comprobantes SET estado = 'anulado', sunat_descripcion = $2, actualizado_en = now() WHERE id = $1`, [id, `Anulado en el sistema: ${motivo}`]);
    } else {
      const tabla = clase === 'resumen' ? 'resumenes_diarios' : 'comunicaciones_baja';
      const prefijo = clase === 'resumen' ? 'RC' : 'RA';
      const correlativo = await siguienteCorrelativo(c, tabla, hoy);
      const items = clase === 'resumen' ? [{ ...detalleResumen(comprobante, '3'), comprobante_id: id }] : [detalleBaja(comprobante, motivo)];
      documentoId = await insertarFila(c, tabla, {
        fecha_referencia: comprobante.fecha_emision,
        fecha_generacion: hoy,
        correlativo,
        identificador: `${prefijo}-${hoy.replace(/-/g, '')}-${String(correlativo).padStart(3, '0')}`,
        estado: 'pendiente',
        items: JSON.stringify(items),
        entorno: comprobante.entorno,
        ...(clase === 'baja' ? { comprobante_id: id } : {}),
      });
      await c.query(`UPDATE comprobantes SET estado = 'por_anular', actualizado_en = now() WHERE id = $1`, [id]);
      if (clase === 'resumen') await encolar(c, 'enviar_resumen', { resumen_id: documentoId });
      else await encolar(c, 'enviar_baja', { baja_id: documentoId });
    }

    await reponerStock(c, comprobante, usuario.id);
    await registrarAuditoria(c, { usuarioId: usuario.id, accion: 'comprobante.anular', entidad: 'comprobantes', entidadId: id, detalle: { motivo, clase, documento_id: documentoId } });
    return { clase, id: documentoId, comprobante: await comprobanteCompleto(c, id) };
  });
}

const FORMATOS_PDF = { 'pdf-a4': 'a4', 'pdf-ticket80': 'ticket80', 'pdf-ticket58': 'ticket58' } as const;

export async function urlArchivo(usuario: UsuarioAutenticado, id: string, tipo: keyof typeof FORMATOS_PDF | 'xml' | 'cdr') {
  const { comprobante, ruc } = await withTransaction(async (c) => {
    const fila = await comprobanteCompleto(c, id);
    asegurarAcceso(usuario, fila);
    const empresa = await c.query<{ ruc: string }>('SELECT ruc FROM empresa WHERE id = 1');
    return { comprobante: fila, ruc: empresa.rows[0]!.ruc };
  });
  if (tipo === 'xml' || tipo === 'cdr') {
    const ruta = tipo === 'xml' ? comprobante.xml_path : comprobante.cdr_path;
    if (!ruta) throw new ErrorApi(404, 'ARCHIVO_NO_DISPONIBLE', tipo === 'xml' ? 'El XML aún no está disponible.' : 'SUNAT aún no devolvió el CDR.');
    return { url: await urlFirmada(ruta) };
  }
  const formato = FORMATOS_PDF[tipo];
  const ruta = `${comprobante.entorno}/${ruc}/${ruc}-${comprobante.tipo}-${comprobante.serie}-${comprobante.correlativo}-${formato}.pdf`;
  await subirDocumento(ruta, await generarPdfComprobante(id, formato), 'application/pdf');
  return { url: await urlFirmada(ruta) };
}
