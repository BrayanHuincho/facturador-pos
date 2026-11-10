import { ErrorDefinitivo, ErrorReintentable } from '../cola/errores.js';
import { codigoLimpio, estadoPorCodigo, explicarCodigo, numeroCompleto } from './catalogos.js';
import { cdrDeOtroComprobante, codigoDelCdr, extensionCdr } from './cdr.js';
import { clasificarRespuesta, codigoDeRespuesta, textoDeRespuesta } from './clasificacion.js';
import { ErrorRedSunat, type CredencialesSunat, type EmisorSunat, type LlamarGateway, type RespuestaSunat } from './cliente.js';
import { cadenaQr, documentoComprobante, emisorDe, nombreArchivo, vaEnResumen, type ComprobanteEnvio, type EmpresaSunat } from './documento.js';

export const ENVIO_VENCIDO_MS = 5 * 60_000;

export type CamposComprobante = Partial<{
  estado: string;
  sunat_codigo: string | null;
  sunat_descripcion: string | null;
  sunat_notas: string[];
  hash: string | null;
  qr: string | null;
  xml_path: string | null;
  cdr_path: string | null;
  pdf_path: string | null;
  entorno: string;
}>;

export interface DepsEnvio {
  leerComprobante(id: string): Promise<ComprobanteEnvio | null>;
  leerContexto(): Promise<{ empresa: EmpresaSunat; entorno: 'beta' | 'produccion'; envio_boletas: 'individual' | 'resumen_diario' }>;
  credenciales(): Promise<CredencialesSunat>;
  reclamarEnvio(id: string, vencidoMs: number): Promise<boolean>;
  actualizar(id: string, campos: CamposComprobante, estadosPrevios: string[]): Promise<void>;
  llamar: LlamarGateway;
  guardar(ruta: string, base64: string, tipo: string): Promise<string>;
  generarYGuardarPdf(c: ComprobanteEnvio, ruc: string, entorno: string): Promise<void>;
  aviso(mensaje: string): void;
}

const YA_RESUELTOS = new Set(['aceptado', 'observado', 'rechazado', 'anulado', 'no_aplica', 'por_anular']);
const REINTENTABLES = ['pendiente', 'enviando'];

const mensaje = (e: unknown): string => (e instanceof Error ? e.message : String(e));

async function guardarSinPerder(d: DepsEnvio, ruta: string, base64: string, tipo: string, previo: string | null): Promise<string | null> {
  try {
    return await d.guardar(ruta, base64, tipo);
  } catch (e) {
    d.aviso(`No se pudo guardar ${ruta}: ${mensaje(e)}`);
    return previo;
  }
}

async function firmarParaResumen(c: ComprobanteEnvio, d: DepsEnvio, empresa: EmpresaSunat, entorno: string): Promise<string> {
  await d.actualizar(c.id, { estado: 'por_resumen', entorno }, ['pendiente', 'error', 'por_resumen']);
  try {
    const { documento } = documentoComprobante(c, empresa.igv_porcentaje);
    const r = await d.llamar('firmar', { credenciales: await d.credenciales(), emisor: emisorDe(empresa, c.establecimiento_codigo), documento });
    if (r.xml) {
      const xml_path = await guardarSinPerder(d, `${entorno}/${empresa.ruc}/${nombreArchivo(empresa.ruc, c)}.xml`, r.xml, 'application/xml', c.xml_path);
      await d.actualizar(c.id, { xml_path, hash: r.hash ?? c.hash, qr: cadenaQr(empresa.ruc, c, r.hash ?? c.hash) }, ['por_resumen']);
    }
  } catch (e) {
    if (e instanceof ErrorReintentable) throw e;
    await d.actualizar(c.id, { sunat_descripcion: mensaje(e) }, ['por_resumen']);
  }
  return 'por_resumen';
}

async function recuperarPresentado(c: ComprobanteEnvio, d: DepsEnvio, credenciales: CredencialesSunat, emisor: EmisorSunat, original: RespuestaSunat): Promise<RespuestaSunat> {
  if (credenciales.entorno !== 'PRODUCCION') return original;
  let q: RespuestaSunat;
  try {
    q = await d.llamar('consulta-cpe', {
      credenciales,
      emisor,
      documento: { tipo_documento: c.tipo, serie: c.serie, correlativo: c.correlativo, con_cdr: true },
    });
  } catch (e) {
    if (e instanceof ErrorDefinitivo) return original;
    throw e;
  }
  if (!q.cdr) {
    if (clasificarRespuesta(q).tipo === 'reintentar') throw new ErrorRedSunat(`SUNAT respondió ${codigoDeRespuesta(q)} al consultar el CDR`);
    return { ...original, descripcion: [original.descripcion, q.descripcion].filter(Boolean).join(' · ') };
  }
  const numero = numeroCompleto(c.serie, c.correlativo);
  if (cdrDeOtroComprobante(q.cdr, c.cliente_numero_documento) === true) {
    return { ...original, descripcion: `SUNAT ya tiene otro comprobante ${numero} emitido a otro cliente` };
  }
  const codigo = codigoLimpio(q.cdr_codigo) ?? codigoDelCdr(q.cdr);
  if (codigo === null) return { ...original, descripcion: `No se pudo leer el código del CDR recuperado de ${numero}` };
  return { ...q, exito: true, xml: original.xml ?? q.xml, hash: original.hash ?? q.hash, codigo, descripcion: q.cdr_descripcion ?? q.descripcion, error: null };
}

async function aplicarRespuesta(c: ComprobanteEnvio, r: RespuestaSunat, d: DepsEnvio, empresa: EmpresaSunat, entorno: string): Promise<string> {
  const nombre = nombreArchivo(empresa.ruc, c);
  const carpeta = `${entorno}/${empresa.ruc}`;
  const xml_path = r.xml ? await guardarSinPerder(d, `${carpeta}/${nombre}.xml`, r.xml, 'application/xml', c.xml_path) : c.xml_path;
  const extension = r.cdr ? extensionCdr(r.cdr) : 'zip';
  const cdr_path = r.cdr ? await guardarSinPerder(d, `${carpeta}/R-${nombre}.${extension}`, r.cdr, extension === 'zip' ? 'application/zip' : 'application/xml', c.cdr_path) : c.cdr_path;
  const codigo = codigoDeRespuesta(r);
  const estado = estadoPorCodigo(codigo, r.exito);
  const hash = r.hash ?? c.hash;
  const aceptado = estado === 'aceptado' || estado === 'observado';
  await d.actualizar(
    c.id,
    {
      estado,
      sunat_codigo: codigo,
      sunat_descripcion: aceptado ? textoDeRespuesta(r) : [textoDeRespuesta(r), explicarCodigo(codigo)].filter(Boolean).join('. '),
      sunat_notas: r.notas ?? [],
      hash,
      qr: cadenaQr(empresa.ruc, c, hash),
      xml_path,
      cdr_path,
      entorno,
    },
    ['enviando'],
  );
  if (aceptado) {
    try {
      await d.generarYGuardarPdf({ ...c, estado, hash }, empresa.ruc, entorno);
    } catch (e) {
      d.aviso(`PDF de ${nombre}: ${mensaje(e)}`);
    }
  }
  return estado;
}

export async function enviarComprobante(id: string, d: DepsEnvio): Promise<string | null> {
  const c = await d.leerComprobante(id);
  if (!c) return null;
  if (YA_RESUELTOS.has(c.estado) || c.tipo === 'NV' || c.resumen_id) return c.estado;

  const { empresa, entorno, envio_boletas } = await d.leerContexto();
  if (c.entorno && c.entorno !== entorno) {
    await d.actualizar(id, { estado: 'error', sunat_descripcion: `El comprobante se emitió en ${c.entorno} y el sistema está en ${entorno}: no se envía.` }, ['pendiente', 'error', 'enviando', 'por_resumen']);
    return 'error';
  }
  if (c.estado === 'por_resumen' || (envio_boletas === 'resumen_diario' && vaEnResumen(c))) return firmarParaResumen(c, d, empresa, entorno);

  if (!(await d.reclamarEnvio(id, ENVIO_VENCIDO_MS))) {
    throw new ErrorReintentable(`El comprobante ${numeroCompleto(c.serie, c.correlativo)} ya se está enviando`);
  }

  let r: RespuestaSunat;
  try {
    const credenciales = await d.credenciales();
    const emisor = emisorDe(empresa, c.establecimiento_codigo);
    const { ruta, documento } = documentoComprobante(c, empresa.igv_porcentaje);
    r = await d.llamar(ruta, { credenciales, emisor, documento });
    const decision = clasificarRespuesta(r);
    if (decision.tipo === 'reintentar') throw new ErrorRedSunat(`SUNAT respondió ${codigoDeRespuesta(r)}${r.descripcion ? ` (${r.descripcion})` : ''}`);
    if (decision.tipo === 'recuperar_cdr') r = await recuperarPresentado(c, d, credenciales, emisor, r);
  } catch (e) {
    if (e instanceof ErrorDefinitivo) {
      await d.actualizar(id, { estado: 'error', sunat_descripcion: mensaje(e), entorno }, ['enviando']);
      return 'error';
    }
    await d.actualizar(id, { estado: 'pendiente', sunat_descripcion: `${mensaje(e)}. Se reintentará automáticamente.` }, ['enviando']);
    throw e instanceof ErrorReintentable ? e : new ErrorRedSunat(mensaje(e));
  }
  return aplicarRespuesta(c, r, d, empresa, entorno);
}

export async function marcarFalloEnvio(id: string, detalle: string, d: Pick<DepsEnvio, 'actualizar'>): Promise<void> {
  await d.actualizar(id, { estado: 'error', sunat_descripcion: `${detalle}. Se agotaron los reintentos: usa Reenviar.` }, REINTENTABLES);
}
