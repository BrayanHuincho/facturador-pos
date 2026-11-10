import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { encolar } from '../../cola/encolar.js';
import { pool, withTransaction } from '../../db/pool.js';
import { requerirRol } from '../../http/auth.js';
import { ErrorApi } from '../../http/errores.js';
import { generarResumenDiario } from './servicio.js';

const LIMITE_LISTADO = 100;
const COLUMNAS = `id, fecha_referencia::text, fecha_generacion::text, correlativo, identificador, estado, ticket, sunat_codigo, sunat_descripcion, xml_path, cdr_path, items, entorno, creado_en`;

const cuerpoResumen = z.object({ fecha: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional() });
const parametrosId = z.object({ id: z.uuid() });

export async function resumenesRutas(app: FastifyInstance): Promise<void> {
  const soloGestion = { preHandler: requerirRol('admin', 'contador') };

  app.get('/resumenes', soloGestion, async () => {
    const { rows } = await pool.query(`select ${COLUMNAS} from resumenes_diarios order by fecha_referencia desc, correlativo desc limit ${LIMITE_LISTADO}`);
    return rows;
  });

  app.post('/resumenes', soloGestion, async (request) => {
    const cuerpo = cuerpoResumen.safeParse(request.body ?? {});
    if (!cuerpo.success) throw new ErrorApi(422, 'DATOS_INVALIDOS', 'La fecha debe tener el formato AAAA-MM-DD.');
    return { resumenes: await generarResumenDiario(cuerpo.data.fecha) };
  });

  app.post('/resumenes/:id/consultar', soloGestion, async (request) => {
    const parametros = parametrosId.safeParse(request.params);
    if (!parametros.success) throw new ErrorApi(422, 'DATOS_INVALIDOS', 'Identificador no válido.');
    const { id } = parametros.data;
    const { rows } = await pool.query<{ ticket: string | null }>(`select ticket from resumenes_diarios where id = $1`, [id]);
    if (!rows[0]) throw new ErrorApi(404, 'RESUMEN_NO_ENCONTRADO', 'Resumen no encontrado.');
    if (!rows[0].ticket) throw new ErrorApi(409, 'RESUMEN_SIN_TICKET', 'El resumen aún no tiene ticket de SUNAT.');
    await withTransaction((c) => encolar(c, 'consultar_ticket', { clase: 'resumen', id }));
    return { encolado: true };
  });

  app.get('/bajas', soloGestion, async () => {
    const { rows } = await pool.query(`select ${COLUMNAS}, comprobante_id from comunicaciones_baja order by fecha_referencia desc, correlativo desc limit ${LIMITE_LISTADO}`);
    return rows;
  });
}
