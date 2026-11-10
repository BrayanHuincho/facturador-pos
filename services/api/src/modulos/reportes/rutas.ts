import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { ErrorApi } from '../../http/errores.js';
import { usuarioFiltrado } from '../caja/calculos.js';
import { validar } from '../caja/validacion.js';
import { construirKpis, esFechaValida, resolverRango } from './calculos.js';
import { generarCsv } from './csv.js';
import {
  ENCABEZADOS_EXPORTACION,
  consultarExportacion,
  consultarTotalesPorTipo,
  consultarVentas,
  type FiltroReporte,
} from './repositorio.js';

const fechaConsulta = z.string().refine(esFechaValida, { message: 'Debe ser una fecha AAAA-MM-DD válida' }).optional();
const esquemaRango = z.object({ desde: fechaConsulta, hasta: fechaConsulta });
const esquemaVentas = esquemaRango.extend({
  agrupar: z.enum(['dia', 'producto', 'medio', 'usuario']).default('dia'),
});

function construirFiltro(
  request: FastifyRequest,
  consulta: { desde?: string | undefined; hasta?: string | undefined },
): FiltroReporte {
  const rango = resolverRango(consulta, new Date());
  if (!rango) throw new ErrorApi(400, 'RANGO_INVALIDO', 'La fecha inicial no puede ser posterior a la final');
  return { ...rango, usuarioId: usuarioFiltrado(request.usuario) };
}

export async function reportesRutas(app: FastifyInstance): Promise<void> {
  app.get('/reportes/resumen', async (request) => {
    const filtro = construirFiltro(request, validar(esquemaRango, request.query));
    const totales = await consultarTotalesPorTipo(filtro);
    return { desde: filtro.desde, hasta: filtro.hasta, ...construirKpis(totales) };
  });

  app.get('/reportes/ventas', async (request) => {
    const consulta = validar(esquemaVentas, request.query);
    const filtro = construirFiltro(request, consulta);
    const filas = await consultarVentas(filtro, consulta.agrupar);
    return { desde: filtro.desde, hasta: filtro.hasta, agrupar: consulta.agrupar, filas };
  });

  app.get('/reportes/exportar', async (request, reply) => {
    const filtro = construirFiltro(request, validar(esquemaRango, request.query));
    const filas = await consultarExportacion(filtro);
    return reply
      .header('Content-Type', 'text/csv; charset=utf-8')
      .header('Content-Disposition', `attachment; filename="ventas_${filtro.desde}_${filtro.hasta}.csv"`)
      .send(generarCsv(ENCABEZADOS_EXPORTACION, filas));
  });
}
