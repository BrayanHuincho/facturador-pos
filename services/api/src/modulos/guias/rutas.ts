import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { encolar } from '../../cola/encolar.js';
import { pool, withTransaction } from '../../db/pool.js';
import { ErrorApi } from '../../http/errores.js';
import { generarPdfGuia } from '../../pdf/generar.js';
import { subirDocumento, urlFirmada } from '../../storage/archivos.js';
import { MOTIVOS_TRASLADO, numeroCompleto } from '../../sunat/catalogos.js';
import { erroresGuia } from './documento.js';
import { hoyLima } from '../resumenes/servicio.js';

const textoRequerido = z.string().trim().min(1);
const fecha = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const ubigeo = z.string().regex(/^\d{6}$/);

const cuerpoGuia = z.object({
  establecimiento_id: z.uuid().optional(),
  serie: z.string().length(4).optional(),
  fecha_traslado: fecha,
  motivo_codigo: z.string().refine((m) => m in MOTIVOS_TRASLADO),
  modalidad: z.enum(['01', '02']),
  peso_total: z.coerce.number().positive(),
  unidad_peso: z.enum(['KGM', 'TNE']).default('KGM'),
  bultos: z.coerce.number().int().positive().optional(),
  partida_ubigeo: ubigeo,
  partida_direccion: textoRequerido,
  llegada_ubigeo: ubigeo,
  llegada_direccion: textoRequerido,
  destinatario_tipo_documento: z.enum(['1', '4', '6', '7']),
  destinatario_numero_documento: textoRequerido,
  destinatario_nombre: textoRequerido,
  transportista: z.object({ ruc: z.string().regex(/^\d{11}$/), razon_social: textoRequerido, mtc: z.string().optional() }).nullish(),
  conductor: z.object({ tipo_documento: z.enum(['1', '4', '7']).default('1'), numero: textoRequerido, nombres: textoRequerido, apellidos: textoRequerido, licencia: textoRequerido }).nullish(),
  vehiculo_placa: z.string().trim().min(5).max(10).nullish(),
  vehiculo_m1l: z.boolean().default(false),
  comprobante_id: z.uuid().nullish(),
  items: z
    .array(z.object({ producto_id: z.uuid().nullish(), codigo: z.string().nullish(), descripcion: textoRequerido, unidad: z.string().default('NIU'), cantidad: z.coerce.number().positive() }))
    .min(1),
});

const COLUMNAS_ARCHIVO: Record<string, string> = { pdf: 'pdf_path', xml: 'xml_path', cdr: 'cdr_path' };

const ESTADOS_CON_PDF = new Set(['aceptado', 'observado', 'anulado']);

const parametrosId = z.object({ id: z.uuid() });

async function urlPdfGuia(guia: { id: string; serie: string; correlativo: number; entorno: string | null; pdf_path: string | null }): Promise<string> {
  const { rows } = await pool.query<{ ruc: string }>('select ruc from empresa where id = 1');
  const ruc = rows[0]?.ruc ?? '';
  const ruta = guia.pdf_path ?? `${guia.entorno ?? 'beta'}/${ruc}/${ruc}-09-${numeroCompleto(guia.serie, guia.correlativo)}.pdf`;
  await subirDocumento(ruta, await generarPdfGuia(guia.id, 'a4'), 'application/pdf');
  return urlFirmada(ruta);
}

function idDe(request: FastifyRequest): string {
  const parametros = parametrosId.safeParse(request.params);
  if (!parametros.success) throw new ErrorApi(422, 'DATOS_INVALIDOS', 'Identificador no válido.');
  return parametros.data.id;
}

async function obtenerGuia(id: string, request: FastifyRequest) {
  const { rows } = await pool.query(
    `select g.*, g.fecha_emision::text as fecha_emision, g.fecha_traslado::text as fecha_traslado,
            coalesce((select json_agg(i) from guia_items i where i.guia_id = g.id), '[]'::json) as items
       from guias_remision g where g.id = $1`,
    [id],
  );
  const guia = rows[0];
  if (!guia || (request.usuario.rol === 'cajero' && guia.usuario_id !== request.usuario.id)) {
    throw new ErrorApi(404, 'GUIA_NO_ENCONTRADA', 'Guía de remisión no encontrada.');
  }
  return guia;
}

export async function guiasRutas(app: FastifyInstance): Promise<void> {
  app.post('/guias', async (request, respuesta) => {
    const analisis = cuerpoGuia.safeParse(request.body);
    if (!analisis.success) throw new ErrorApi(422, 'DATOS_INVALIDOS', 'Los datos de la guía no son válidos.', analisis.error.issues);
    const dto = analisis.data;
    const { usuario } = request;
    const establecimiento = usuario.rol === 'admin' ? (dto.establecimiento_id ?? usuario.establecimiento_id) : usuario.establecimiento_id;
    if (!establecimiento) throw new ErrorApi(422, 'SIN_ESTABLECIMIENTO', 'Indica el establecimiento de la guía.');

    const id = await withTransaction(async (c) => {
      const { rows: empresa } = await c.query<{ ruc: string }>(`select ruc from empresa where id = 1`);
      const errores = erroresGuia(dto, empresa[0].ruc, hoyLima());
      if (errores.length) throw new ErrorApi(422, 'GUIA_INVALIDA', errores[0], errores);
      const { rows: series } = await c.query<{ serie: string; correlativo: number }>(
        `update series s set ultimo = s.ultimo + 1
           from (select id from series
                  where tipo = '09' and activa and establecimiento_id = $1 and ($2::text is null or serie = $2)
                  order by serie limit 1 for update) elegida
          where s.id = elegida.id
          returning s.serie, s.ultimo as correlativo`,
        [establecimiento, dto.serie ?? null],
      );
      if (!series[0]) throw new ErrorApi(422, 'SERIE_NO_DISPONIBLE', 'No hay una serie de guía activa para este establecimiento.');
      const conductor = dto.vehiculo_m1l ? { vehiculo_m1l: true } : (dto.conductor ?? null);
      const { rows } = await c.query<{ id: string }>(
        `insert into guias_remision (establecimiento_id, usuario_id, serie, correlativo, fecha_emision, fecha_traslado, motivo_codigo, modalidad, peso_total, unidad_peso, bultos,
                                     partida_ubigeo, partida_direccion, llegada_ubigeo, llegada_direccion, destinatario_tipo_documento, destinatario_numero_documento, destinatario_nombre,
                                     transportista, conductor, vehiculo_placa, comprobante_id, entorno)
         values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19::jsonb, $20::jsonb, $21, $22,
                 (select entorno from configuracion_sunat where id = 1))
         returning id`,
        [
          establecimiento,
          usuario.id,
          series[0].serie,
          series[0].correlativo,
          hoyLima(),
          dto.fecha_traslado,
          dto.motivo_codigo,
          dto.modalidad,
          dto.peso_total,
          dto.unidad_peso,
          dto.bultos ?? null,
          dto.partida_ubigeo,
          dto.partida_direccion,
          dto.llegada_ubigeo,
          dto.llegada_direccion,
          dto.destinatario_tipo_documento,
          dto.destinatario_numero_documento,
          dto.destinatario_nombre,
          dto.transportista ? JSON.stringify(dto.transportista) : null,
          conductor ? JSON.stringify(conductor) : null,
          dto.vehiculo_placa ?? null,
          dto.comprobante_id ?? null,
        ],
      );
      for (const item of dto.items) {
        await c.query(`insert into guia_items (guia_id, producto_id, codigo, descripcion, unidad, cantidad) values ($1, $2, $3, $4, $5, $6)`, [
          rows[0].id,
          item.producto_id ?? null,
          item.codigo ?? null,
          item.descripcion,
          item.unidad,
          item.cantidad,
        ]);
      }
      await encolar(c, 'enviar_guia', { guia_id: rows[0].id });
      return rows[0].id;
    });
    respuesta.status(201);
    return obtenerGuia(id, request);
  });

  app.get('/guias/:id', async (request) => obtenerGuia(idDe(request), request));

  app.get('/guias/:id/archivo/:tipo', async (request) => {
    const guia = await obtenerGuia(idDe(request), request);
    const { tipo } = request.params as { tipo: string };
    const columna = COLUMNAS_ARCHIVO[tipo];
    if (!columna) throw new ErrorApi(422, 'TIPO_ARCHIVO_INVALIDO', 'Tipo de archivo no válido.');
    if (tipo === 'pdf' && (guia.pdf_path || ESTADOS_CON_PDF.has(guia.estado))) return { url: await urlPdfGuia(guia) };
    const ruta = guia[columna] as string | null;
    if (!ruta) throw new ErrorApi(404, 'ARCHIVO_NO_DISPONIBLE', 'El archivo aún no está disponible.');
    return { url: await urlFirmada(ruta) };
  });

  app.post('/guias/:id/reenviar', async (request) => {
    const guia = await obtenerGuia(idDe(request), request);
    if (['aceptado', 'observado', 'rechazado', 'anulado'].includes(guia.estado)) {
      throw new ErrorApi(409, 'GUIA_NO_REENVIABLE', 'La guía ya tiene una respuesta definitiva de SUNAT.');
    }
    await withTransaction((c) => encolar(c, 'enviar_guia', { guia_id: guia.id }));
    return { encolado: true };
  });
}
