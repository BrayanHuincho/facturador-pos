import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { consultarDocumento, tipoDeConsulta } from './servicio.js';

const parametros = z.object({ tipo: z.string().min(1).max(3), numero: z.string().regex(/^\d{8,11}$/) });

export async function consultasRutas(app: FastifyInstance) {
  app.get('/consultas/documento/:tipo/:numero', { config: { rateLimit: { max: 60, timeWindow: '1 minute' } } }, async (request) => {
    const { tipo, numero } = parametros.parse(request.params);
    return consultarDocumento(tipoDeConsulta(tipo), numero);
  });
}
