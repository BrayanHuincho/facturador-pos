import type { FastifyInstance } from 'fastify';
import type { PoolClient } from 'pg';
import { z } from 'zod';
import { registrarAuditoria } from '../../db/auditoria.js';
import { pool, withTransaction } from '../../db/pool.js';
import { requerirRol } from '../../http/auth.js';
import { ErrorApi } from '../../http/errores.js';
import { errorSerie, TIPOS_SERIE } from './reglas.js';
import type { TipoSerie } from './reglas.js';

const serieTexto = z.string().trim().toUpperCase();
const ultimo = z.number().int().min(0);

const esquemaCrear = z.object({
  establecimiento_id: z.uuid(),
  tipo: z.enum(TIPOS_SERIE),
  serie: serieTexto,
  activa: z.boolean().default(true),
  ultimo: ultimo.default(0),
});

const esquemaActualizar = z.object({
  establecimiento_id: z.uuid().optional(),
  tipo: z.enum(TIPOS_SERIE).optional(),
  serie: serieTexto.optional(),
  activa: z.boolean().optional(),
  ultimo: ultimo.optional(),
});

const parametrosId = z.object({ id: z.uuid() });

type FilaSerie = { id: string; establecimiento_id: string; tipo: TipoSerie; serie: string; ultimo: number; activa: boolean };

const COLUMNAS = 'id, establecimiento_id, tipo, serie, ultimo, activa';

function validarFormato(tipo: TipoSerie, serie: string) {
  const problema = errorSerie(tipo, serie);
  if (problema) throw new ErrorApi(400, 'SERIE_INVALIDA', problema);
}

async function serieConDocumentos(c: PoolClient, fila: FilaSerie): Promise<boolean> {
  const consulta =
    fila.tipo === '09'
      ? await c.query('select 1 from guias_remision where serie = $1 limit 1', [fila.serie])
      : await c.query('select 1 from comprobantes where tipo = $1 and serie = $2 limit 1', [fila.tipo, fila.serie]);
  return consulta.rows.length > 0;
}

export async function seriesRutas(app: FastifyInstance) {
  const soloAdmin = { preHandler: requerirRol('admin') };

  app.get('/series', soloAdmin, async () => {
    const { rows } = await pool.query<FilaSerie>(`select ${COLUMNAS} from series order by tipo, serie`);
    return rows;
  });

  app.post('/series', soloAdmin, async (request, reply) => {
    const datos = esquemaCrear.parse(request.body);
    validarFormato(datos.tipo, datos.serie);
    const creada = await withTransaction(async (c) => {
      const { rows } = await c.query<FilaSerie>(
        `insert into series (establecimiento_id, tipo, serie, activa, ultimo) values ($1, $2, $3, $4, $5) returning ${COLUMNAS}`,
        [datos.establecimiento_id, datos.tipo, datos.serie, datos.activa, datos.ultimo],
      );
      const fila = rows[0] as FilaSerie;
      await registrarAuditoria(c, {
        usuarioId: request.usuario.id,
        accion: 'SERIE_CREADA',
        entidad: 'series',
        entidadId: fila.id,
        detalle: { tipo: fila.tipo, serie: fila.serie, ultimo: fila.ultimo },
      });
      return fila;
    });
    return reply.status(201).send(creada);
  });

  app.patch('/series/:id', soloAdmin, async (request) => {
    const { id } = parametrosId.parse(request.params);
    const datos = esquemaActualizar.parse(request.body);
    return withTransaction(async (c) => {
      const { rows } = await c.query<FilaSerie>(`select ${COLUMNAS} from series where id = $1 for update`, [id]);
      const actual = rows[0];
      if (!actual) throw new ErrorApi(404, 'SERIE_NO_ENCONTRADA', 'La serie no existe.');
      validarFormato(datos.tipo ?? actual.tipo, datos.serie ?? actual.serie);

      const cambiaNumeracion =
        (datos.ultimo !== undefined && datos.ultimo !== actual.ultimo) ||
        (datos.tipo !== undefined && datos.tipo !== actual.tipo) ||
        (datos.serie !== undefined && datos.serie !== actual.serie);
      if (cambiaNumeracion && (await serieConDocumentos(c, actual))) {
        throw new ErrorApi(409, 'SERIE_CON_DOCUMENTOS', 'La serie ya tiene documentos emitidos: su tipo, código y correlativo no se pueden cambiar.');
      }

      const claves = (Object.keys(datos) as (keyof typeof datos)[]).filter((clave) => datos[clave] !== undefined);
      const asignaciones = claves.map((clave, indice) => `${clave} = $${indice + 2}`);
      const actualizada = await c.query<FilaSerie>(
        `update series set ${[...asignaciones, 'actualizado_en = now()'].join(', ')} where id = $1 returning ${COLUMNAS}`,
        [id, ...claves.map((clave) => datos[clave])],
      );
      await registrarAuditoria(c, {
        usuarioId: request.usuario.id,
        accion: 'SERIE_ACTUALIZADA',
        entidad: 'series',
        entidadId: id,
        detalle: { campos: claves, antes: { tipo: actual.tipo, serie: actual.serie, ultimo: actual.ultimo, activa: actual.activa } },
      });
      return actualizada.rows[0] as FilaSerie;
    });
  });
}
