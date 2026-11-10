import { encolar } from '../../cola/encolar.js';
import { ErrorDefinitivo, ErrorReintentable } from '../../cola/errores.js';
import { pool, withTransaction } from '../../db/pool.js';
import { generarPdfGuia } from '../../pdf/generar.js';
import { codigoLimpio, estadoPorCodigo, numeroCompleto } from '../../sunat/catalogos.js';
import { claseDeCodigo } from '../../sunat/catalogos.js';
import { extensionCdr } from '../../sunat/cdr.js';
import { ErrorRedSunat, type RespuestaSunat } from '../../sunat/cliente.js';
import { leerConfiguracionSunat, obtenerCredencialesSunat } from '../../sunat/config.js';
import { exigirCredencialesGuia } from '../../sunat/credenciales.js';
import { guardarBase64, guardarBuffer, leerEmpresa } from '../../sunat/datos.js';
import { emisorDe } from '../../sunat/documento.js';
import { ENVIO_VENCIDO_MS } from '../../sunat/envio.js';
import { llamarGateway } from '../../sunat/gateway.js';
import { documentoGuia, type GuiaEnvio } from './documento.js';

const ESPERA_BASE_CONSULTA_MS = 3_000;
const FINALES = new Set(['aceptado', 'observado', 'rechazado', 'anulado']);
const TOKEN_NO_LISTO = /\[401\]|Token NO existe/i;

type CamposGuia = Partial<Record<'estado' | 'ticket' | 'sunat_codigo' | 'sunat_descripcion' | 'xml_path' | 'cdr_path' | 'pdf_path' | 'qr' | 'entorno', string | null>>;

async function actualizar(id: string, campos: CamposGuia): Promise<void> {
  const claves = Object.keys(campos) as (keyof CamposGuia)[];
  const asignaciones = claves.map((k, i) => `${k} = $${i + 2}`);
  await pool.query(`update guias_remision set ${asignaciones.join(', ')} where id = $1`, [id, ...claves.map((k) => campos[k])]);
}

async function leerGuia(id: string): Promise<GuiaEnvio | null> {
  const { rows } = await pool.query<GuiaEnvio>(
    `select g.id, g.serie, g.correlativo, g.fecha_emision::text, to_char(g.creado_en at time zone 'America/Lima', 'HH24:MI:SS') as hora_emision,
            g.fecha_traslado::text, g.motivo_codigo, g.modalidad, g.peso_total::text, g.unidad_peso, g.bultos,
            g.partida_ubigeo, g.partida_direccion, g.llegada_ubigeo, g.llegada_direccion,
            g.destinatario_tipo_documento, g.destinatario_numero_documento, g.destinatario_nombre,
            g.transportista, g.conductor, g.vehiculo_placa, g.estado, g.ticket, g.xml_path, g.cdr_path, g.entorno,
            e.codigo as establecimiento_codigo, c.tipo as relacionado_tipo,
            case when c.id is null then null else c.serie || '-' || lpad(c.correlativo::text, 6, '0') end as relacionado_numero,
            coalesce((select json_agg(json_build_object('codigo', i.codigo, 'descripcion', i.descripcion, 'unidad', i.unidad, 'cantidad', i.cantidad::text))
                        from guia_items i where i.guia_id = g.id), '[]'::json) as items
       from guias_remision g
       left join establecimientos e on e.id = g.establecimiento_id
       left join comprobantes c on c.id = g.comprobante_id
      where g.id = $1`,
    [id],
  );
  return rows[0] ?? null;
}

async function encolarConsulta(id: string, demoraMs: number): Promise<void> {
  await withTransaction((c) => encolar(c, 'consultar_guia', { guia_id: id }, new Date(Date.now() + demoraMs)));
}

async function reclamar(id: string): Promise<boolean> {
  const { rowCount } = await pool.query(
    `update guias_remision set estado = 'enviando'
      where id = $1 and ticket is null
        and (estado in ('pendiente', 'error')
             or (estado = 'enviando' and actualizado_en < now() - ($2::double precision * interval '1 millisecond')))`,
    [id, ENVIO_VENCIDO_MS],
  );
  return rowCount === 1;
}

export async function enviarGuia(id: string): Promise<void> {
  const g = await leerGuia(id);
  if (!g || FINALES.has(g.estado)) return;
  if (g.ticket) {
    await encolarConsulta(id, 0);
    return;
  }
  const [empresa, configuracion] = await Promise.all([leerEmpresa(), leerConfiguracionSunat(pool)]);
  if (g.entorno && g.entorno !== configuracion.entorno) {
    await actualizar(id, { estado: 'error', sunat_descripcion: `La guía se emitió en ${g.entorno} y el sistema está en ${configuracion.entorno}: no se envía.` });
    return;
  }
  if (!(await reclamar(id))) throw new ErrorReintentable(`La guía ${numeroCompleto(g.serie, g.correlativo)} ya se está enviando`);

  let r: RespuestaSunat;
  try {
    const credenciales = exigirCredencialesGuia(await obtenerCredencialesSunat(pool));
    r = await llamarGateway('guia', { credenciales, emisor: emisorDe(empresa, g.establecimiento_codigo), documento: documentoGuia(g) });
    const codigo = r.codigo ?? r.error?.codigo;
    if (!r.exito && (TOKEN_NO_LISTO.test(r.error?.mensaje ?? '') || claseDeCodigo(codigo) === 'TRANSITORIO')) {
      throw new ErrorRedSunat(r.error?.mensaje ?? `SUNAT respondió ${codigoLimpio(codigo)}`);
    }
  } catch (e) {
    const mensaje = e instanceof Error ? e.message : String(e);
    if (e instanceof ErrorDefinitivo) {
      await actualizar(id, { estado: 'error', sunat_descripcion: mensaje });
      return;
    }
    await actualizar(id, { estado: 'pendiente', sunat_descripcion: `${mensaje}. Se reintentará automáticamente.` });
    throw e instanceof ErrorReintentable ? e : new ErrorRedSunat(mensaje);
  }

  const nombre = `${empresa.ruc}-09-${numeroCompleto(g.serie, g.correlativo)}`;
  const xml_path = r.xml ? await guardarBase64(`${configuracion.entorno}/${empresa.ruc}/${nombre}.xml`, r.xml, 'application/xml').catch(() => g.xml_path) : g.xml_path;
  if (!r.exito || !r.ticket) {
    const codigo = codigoLimpio(r.codigo ?? r.error?.codigo);
    await actualizar(id, { estado: 'error', sunat_codigo: codigo, sunat_descripcion: r.descripcion ?? r.error?.mensaje ?? 'SUNAT no recibió la guía', xml_path, entorno: configuracion.entorno });
    return;
  }
  await actualizar(id, { estado: 'procesando', ticket: r.ticket, xml_path, entorno: configuracion.entorno, sunat_descripcion: null });
  await encolarConsulta(id, ESPERA_BASE_CONSULTA_MS);
}

export async function consultarGuia(id: string): Promise<void> {
  const g = await leerGuia(id);
  if (!g?.ticket || g.estado !== 'procesando') return;
  const [empresa, credenciales] = await Promise.all([leerEmpresa(), obtenerCredencialesSunat(pool)]);
  const r = await llamarGateway('guia-estado', { credenciales: exigirCredencialesGuia(credenciales), emisor: emisorDe(empresa, g.establecimiento_codigo), documento: { ticket: g.ticket } });
  if (r.pendiente) throw new ErrorReintentable('SUNAT aún procesa la guía', ESPERA_BASE_CONSULTA_MS);
  const codigo = codigoLimpio(r.codigo ?? r.error?.codigo);
  if (!r.cdr && claseDeCodigo(codigo) === 'TRANSITORIO') throw new ErrorRedSunat(`SUNAT respondió ${codigo} al consultar la guía`);

  const entorno = g.entorno ?? credenciales.entorno.toLowerCase();
  const nombre = `${empresa.ruc}-09-${numeroCompleto(g.serie, g.correlativo)}`;
  const carpeta = `${entorno}/${empresa.ruc}`;
  const extension = r.cdr ? extensionCdr(r.cdr) : 'zip';
  const cdr_path = r.cdr
    ? await guardarBase64(`${carpeta}/R-${nombre}.${extension}`, r.cdr, extension === 'zip' ? 'application/zip' : 'application/xml').catch(() => g.cdr_path)
    : g.cdr_path;
  const estado = estadoPorCodigo(codigo, Boolean(r.cdr) || r.exito);
  const aceptado = estado === 'aceptado' || estado === 'observado';
  await actualizar(id, { estado, sunat_codigo: codigo, sunat_descripcion: r.descripcion ?? r.error?.mensaje ?? null, cdr_path, qr: r.qr ?? null });
  if (!aceptado) return;
  try {
    const pdf_path = await guardarBuffer(`${carpeta}/${nombre}.pdf`, await generarPdfGuia(id, 'a4'), 'application/pdf');
    await actualizar(id, { pdf_path });
  } catch (e) {
    console.warn(`PDF de la guía ${nombre}: ${e instanceof Error ? e.message : String(e)}`);
  }
}

export async function marcarFalloGuia(id: string, detalle: string): Promise<void> {
  await pool.query(`update guias_remision set estado = 'error', sunat_descripcion = $2 where id = $1 and estado in ('pendiente', 'enviando')`, [id, `${detalle}. Se agotaron los reintentos: usa Reenviar.`]);
}

export async function reencolarGuiasPendientes(): Promise<number> {
  const { rows } = await pool.query<{ id: string }>(
    `select g.id from guias_remision g
      where g.estado = 'procesando' and g.ticket is not null
        and not exists (select 1 from trabajos t where t.tipo = 'consultar_guia' and t.estado in ('pendiente', 'procesando') and t.payload->>'guia_id' = g.id::text)`,
  );
  for (const { id } of rows) await encolarConsulta(id, 0);
  return rows.length;
}
