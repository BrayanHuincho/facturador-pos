import { pool } from '../db/pool.js';
import { generarPdfComprobante } from '../pdf/generar.js';
import { subirDocumento } from '../storage/archivos.js';
import { leerConfiguracionSunat, obtenerCredencialesSunat } from './config.js';
import type { ComprobanteEnvio, EmpresaSunat } from './documento.js';
import type { CamposComprobante, DepsEnvio } from './envio.js';
import { llamarGateway } from './gateway.js';
import { nombreArchivo } from './documento.js';

const INTENTOS_GUARDADO = 3;
const PAUSA_GUARDADO_MS = 500;

const esperar = (ms: number) => new Promise((listo) => setTimeout(listo, ms));

export async function guardarBase64(ruta: string, base64: string, tipo: string): Promise<string> {
  return guardarBuffer(ruta, Buffer.from(base64, 'base64'), tipo);
}

export async function guardarBuffer(ruta: string, contenido: Buffer, tipo: string): Promise<string> {
  for (let intento = 1; ; intento++) {
    try {
      return await subirDocumento(ruta, contenido, tipo);
    } catch (e) {
      if (intento >= INTENTOS_GUARDADO) throw e;
      await esperar(PAUSA_GUARDADO_MS * intento);
    }
  }
}

export async function leerEmpresa(): Promise<EmpresaSunat> {
  const { rows } = await pool.query<EmpresaSunat>(
    `select ruc, razon_social, nombre_comercial, direccion, ubigeo, departamento, provincia, distrito, igv_porcentaje::text from empresa where id = 1`,
  );
  return rows[0];
}

export async function leerComprobanteEnvio(id: string): Promise<ComprobanteEnvio | null> {
  const { rows } = await pool.query<ComprobanteEnvio>(
    `select c.id, c.tipo, c.serie, c.correlativo, c.fecha_emision::text, c.hora_emision::text, c.moneda, c.tipo_cambio::text,
            c.forma_pago, c.cuotas, c.cliente_tipo_documento, c.cliente_numero_documento, c.cliente_nombre, c.cliente_direccion,
            c.op_gravadas::text, c.op_exoneradas::text, c.op_inafectas::text, c.op_gratuitas::text, c.descuento_total::text,
            c.igv::text, c.icbper::text, c.total::text, c.detraccion, c.leyendas, c.afectado_tipo, c.afectado_serie,
            c.afectado_correlativo, c.motivo_codigo, c.motivo_descripcion, c.estado, c.hash, c.xml_path, c.cdr_path, c.pdf_path,
            c.entorno, c.resumen_id, e.codigo as establecimiento_codigo,
            coalesce((select json_agg(json_build_object(
                'codigo', i.codigo, 'descripcion', i.descripcion, 'unidad', i.unidad,
                'cantidad', i.cantidad::text, 'precio_unitario', i.precio_unitario::text, 'valor_unitario', i.valor_unitario::text,
                'descuento', i.descuento::text, 'afectacion', i.afectacion, 'base', i.base::text, 'igv', i.igv::text,
                'icbper', i.icbper::text, 'total', i.total::text) order by i.orden)
              from comprobante_items i where i.comprobante_id = c.id), '[]'::json) as items
       from comprobantes c
       left join establecimientos e on e.id = c.establecimiento_id
      where c.id = $1`,
    [id],
  );
  return rows[0] ?? null;
}

const COLUMNAS_JSON = new Set(['sunat_notas']);

export async function actualizarComprobante(id: string, campos: CamposComprobante, estadosPrevios: string[]): Promise<void> {
  const claves = Object.keys(campos) as (keyof CamposComprobante)[];
  if (!claves.length) return;
  const asignaciones = claves.map((k, i) => `${k} = $${i + 3}${COLUMNAS_JSON.has(k) ? '::jsonb' : ''}`);
  const valores = claves.map((k) => (COLUMNAS_JSON.has(k) ? JSON.stringify(campos[k]) : campos[k]));
  await pool.query(`update comprobantes set ${asignaciones.join(', ')} where id = $1 and estado = any($2::text[])`, [id, estadosPrevios, ...valores]);
}

export const depsEnvio: DepsEnvio = {
  leerComprobante: leerComprobanteEnvio,
  async leerContexto() {
    const [empresa, configuracion] = await Promise.all([leerEmpresa(), leerConfiguracionSunat(pool)]);
    return { empresa, entorno: configuracion.entorno, envio_boletas: configuracion.envio_boletas };
  },
  credenciales: () => obtenerCredencialesSunat(pool),
  async reclamarEnvio(id, vencidoMs) {
    const { rowCount } = await pool.query(
      `update comprobantes set estado = 'enviando', intentos = intentos + 1
        where id = $1 and resumen_id is null
          and (estado in ('pendiente', 'error')
               or (estado = 'enviando' and actualizado_en < now() - ($2::double precision * interval '1 millisecond')))`,
      [id, vencidoMs],
    );
    return rowCount === 1;
  },
  actualizar: actualizarComprobante,
  llamar: llamarGateway,
  guardar: guardarBase64,
  async generarYGuardarPdf(c, ruc, entorno) {
    const pdf = await generarPdfComprobante(c.id, 'a4');
    const pdf_path = await guardarBuffer(`${entorno}/${ruc}/${nombreArchivo(ruc, c)}.pdf`, pdf, 'application/pdf');
    await pool.query(`update comprobantes set pdf_path = $2 where id = $1`, [c.id, pdf_path]);
  },
  aviso: (mensaje) => console.warn(mensaje),
};
