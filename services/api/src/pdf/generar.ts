import { entorno } from '../config/entorno.js';
import { pool } from '../db/pool.js';
import { supabaseAdmin } from '../storage/archivos.js';
import { ErrorDatosSunat, ErrorRedSunat } from '../sunat/cliente.js';
import { formatoValido, peticionComprobante, peticionGuia, peticionVistaPrevia, type ComprobantePdf, type EmpresaPdf, type FormatoPdf, type GuiaPdf, type PeticionPdf } from './peticion.js';

const LIMITE_PDF_MS = 25_000;
const LIMITE_LOGO_MS = 3_000;
const BUCKET_IMAGENES = 'imagenes';

async function leerEmpresaPdf(): Promise<EmpresaPdf & { logo_path: string | null }> {
  const { rows } = await pool.query<EmpresaPdf & { logo_path: string | null }>(
    `select ruc, razon_social, nombre_comercial, direccion, distrito, provincia, departamento, telefono, correo, logo_path, plantilla_pdf from empresa where id = 1`,
  );
  return rows[0];
}

export function logoEnBase64(datos: Buffer): string | null {
  const png = datos.length > 3 && datos[0] === 0x89 && datos[1] === 0x50 && datos[2] === 0x4e && datos[3] === 0x47;
  const jpeg = datos.length > 2 && datos[0] === 0xff && datos[1] === 0xd8 && datos[2] === 0xff;
  return png || jpeg ? datos.toString('base64') : null;
}

async function descargarLogo(logoPath: string | null): Promise<string | null> {
  if (!logoPath) return null;
  try {
    const { data } = supabaseAdmin.storage.from(BUCKET_IMAGENES).getPublicUrl(logoPath);
    const respuesta = await fetch(data.publicUrl, { signal: AbortSignal.timeout(LIMITE_LOGO_MS) });
    return respuesta.ok ? logoEnBase64(Buffer.from(await respuesta.arrayBuffer())) : null;
  } catch {
    return null;
  }
}

export async function pedirPdfAlGateway(peticion: PeticionPdf): Promise<Buffer> {
  let respuesta: Response;
  try {
    respuesta = await fetch(`${entorno.SUNAT_GATEWAY_URL}/pdf`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Token-Interno': entorno.SUNAT_GATEWAY_TOKEN },
      body: JSON.stringify(peticion),
      signal: AbortSignal.timeout(LIMITE_PDF_MS),
    });
  } catch {
    throw new ErrorRedSunat('El servicio de PDF no está disponible');
  }
  const cuerpo = Buffer.from(await respuesta.arrayBuffer());
  if (respuesta.status >= 500) throw new ErrorRedSunat(`El servicio de PDF respondió HTTP ${respuesta.status}`);
  if (!respuesta.ok || cuerpo.subarray(0, 5).toString('latin1') !== '%PDF-') {
    throw new ErrorDatosSunat('PDF', `El servicio de PDF respondió HTTP ${respuesta.status}`);
  }
  return cuerpo;
}

export async function generarPdfComprobante(comprobanteId: string, formato: FormatoPdf | string): Promise<Buffer> {
  const { rows } = await pool.query<ComprobantePdf>(
    `select c.tipo, c.serie, c.correlativo, c.fecha_emision::text, c.hora_emision::text, c.moneda, c.tipo_cambio::text, c.forma_pago, c.cuotas,
            c.cliente_tipo_documento, c.cliente_numero_documento, c.cliente_nombre, c.cliente_direccion,
            c.op_gravadas::text, c.op_exoneradas::text, c.op_inafectas::text, c.op_gratuitas::text, c.descuento_total::text,
            c.igv::text, c.icbper::text, c.total::text, c.detraccion, c.leyendas, c.afectado_tipo, c.afectado_serie, c.afectado_correlativo,
            c.motivo_codigo, c.motivo_descripcion, c.estado, c.hash, c.qr, c.entorno,
            e.direccion as establecimiento_direccion, p.nombre as usuario_nombre,
            (select igv_porcentaje::text from empresa where id = 1) as igv_porcentaje,
            coalesce((select json_agg(json_build_object(
                'codigo', i.codigo, 'descripcion', i.descripcion, 'unidad', i.unidad, 'cantidad', i.cantidad::text,
                'precio_unitario', i.precio_unitario::text, 'valor_unitario', i.valor_unitario::text, 'descuento', i.descuento::text,
                'afectacion', i.afectacion, 'total', i.total::text) order by i.orden)
              from comprobante_items i where i.comprobante_id = c.id), '[]'::json) as items
       from comprobantes c
       left join establecimientos e on e.id = c.establecimiento_id
       left join perfiles p on p.id = c.usuario_id
      where c.id = $1`,
    [comprobanteId],
  );
  if (!rows[0]) throw new ErrorDatosSunat('COMPROBANTE_NO_ENCONTRADO', 'Comprobante no encontrado');
  const empresa = await leerEmpresaPdf();
  return pedirPdfAlGateway(peticionComprobante(rows[0], empresa, formatoValido(formato), await descargarLogo(empresa.logo_path)));
}

export async function generarPdfVistaPrevia(comprobante: ComprobantePdf, formato: FormatoPdf | string): Promise<Buffer> {
  const empresa = await leerEmpresaPdf();
  return pedirPdfAlGateway(peticionVistaPrevia(comprobante, empresa, formatoValido(formato), await descargarLogo(empresa.logo_path)));
}

export async function generarPdfGuia(guiaId: string, formato: FormatoPdf | string = 'a4'): Promise<Buffer> {
  const { rows } = await pool.query<GuiaPdf>(
    `select g.serie, g.correlativo, g.fecha_emision::text, g.fecha_traslado::text, g.motivo_codigo, g.modalidad, g.peso_total::text, g.unidad_peso, g.bultos,
            g.partida_ubigeo, g.partida_direccion, g.llegada_ubigeo, g.llegada_direccion,
            g.destinatario_tipo_documento, g.destinatario_numero_documento, g.destinatario_nombre,
            g.transportista, g.conductor, g.vehiculo_placa, g.estado, null::text as hash, g.qr, g.entorno,
            e.direccion as establecimiento_direccion,
            (select case c.tipo when '03' then 'Boleta ' else 'Factura ' end || c.serie || '-' || lpad(c.correlativo::text, 6, '0')
               from comprobantes c where c.id = g.comprobante_id) as relacionado,
            coalesce((select json_agg(json_build_object('codigo', i.codigo, 'descripcion', i.descripcion, 'unidad', i.unidad, 'cantidad', i.cantidad::text))
              from guia_items i where i.guia_id = g.id), '[]'::json) as items
       from guias_remision g
       left join establecimientos e on e.id = g.establecimiento_id
      where g.id = $1`,
    [guiaId],
  );
  if (!rows[0]) throw new ErrorDatosSunat('GUIA_NO_ENCONTRADA', 'Guía no encontrada');
  const empresa = await leerEmpresaPdf();
  return pedirPdfAlGateway(peticionGuia(rows[0], empresa, formatoValido(formato), await descargarLogo(empresa.logo_path)));
}
