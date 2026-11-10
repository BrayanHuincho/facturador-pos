import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import multipart from '@fastify/multipart';
import rateLimit from '@fastify/rate-limit';
import Fastify from 'fastify';
import type { FastifyInstance, FastifyPluginAsync } from 'fastify';
import { entorno } from '../config/entorno.js';
import { registrarAutenticacion } from './auth.js';
import { registrarErrores } from './errores.js';
import { opcionesRegistro } from './registro.js';

const LIMITE_POR_MINUTO = 600;
const BYTES_MAXIMOS_CERTIFICADO = 256 * 1024;

export async function crearApp(registrarRutas: FastifyPluginAsync): Promise<FastifyInstance> {
  const app = Fastify({
    logger: entorno.NODE_ENV === 'test' ? false : opcionesRegistro(entorno.LOG_LEVEL),
    trustProxy: entorno.TRUST_PROXY,
  });

  registrarErrores(app);

  await app.register(helmet);
  await app.register(cors, {
    origin: entorno.CORS_ORIGENES.split(',').map((origen) => origen.trim()).filter(Boolean),
    methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  });
  await app.register(rateLimit, {
    global: true,
    max: LIMITE_POR_MINUTO,
    timeWindow: '1 minute',
    errorResponseBuilder: (_request, contexto) =>
      Object.assign(new Error(`Demasiadas solicitudes. Intenta de nuevo en ${contexto.after}.`), {
        statusCode: 429,
        code: 'LIMITE_EXCEDIDO',
      }),
  });
  await app.register(multipart, {
    limits: { fileSize: BYTES_MAXIMOS_CERTIFICADO, files: 1, fields: 5 },
  });

  registrarAutenticacion(app);

  await app.register(
    async (api) => {
      api.get('/salud', { config: { publica: true, rateLimit: false } }, async () => ({ ok: true, servicio: 'facturador-api' }));
      await api.register(registrarRutas);
    },
    { prefix: '/api/v1' },
  );

  return app;
}
