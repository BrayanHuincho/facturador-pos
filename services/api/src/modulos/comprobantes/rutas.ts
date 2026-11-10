import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { ErrorApi } from '../../http/errores.js';
import { requerirRol } from '../../http/auth.js';
import { ErrorRegla } from '../../dominio/tributos/index.js';
import { emitirNota, emitirVenta, previsualizar, vistaPreviaPdf } from './emision.js';
import { esquemaAnular, esquemaArchivo, esquemaClaveIdempotencia, esquemaId, esquemaNota, esquemaVenta, esquemaVistaPrevia } from './esquemas.js';
import { anular, consultar, obtener, reenviar, urlArchivo } from './gestion.js';

const conReglas =
  <T>(manejador: (request: FastifyRequest, reply: FastifyReply) => Promise<T>) =>
  async (request: FastifyRequest, reply: FastifyReply): Promise<T> => {
    try {
      return await manejador(request, reply);
    } catch (error) {
      if (error instanceof ErrorRegla) throw new ErrorApi(error.status, error.codigo, error.message);
      throw error;
    }
  };

function claveObligatoria(request: FastifyRequest): string {
  const resultado = esquemaClaveIdempotencia.safeParse(request.headers['idempotency-key']);
  if (!resultado.success) throw new ErrorApi(400, 'IDEMPOTENCY_KEY_REQUERIDA', 'La cabecera Idempotency-Key es obligatoria.');
  return resultado.data;
}

function claveOpcional(request: FastifyRequest): string | null {
  return request.headers['idempotency-key'] === undefined ? null : claveObligatoria(request);
}

export async function comprobantesRutas(app: FastifyInstance) {
  app.post(
    '/comprobantes/previsualizar',
    conReglas(async (request) => previsualizar(esquemaVenta.parse(request.body))),
  );

  app.post(
    '/comprobantes/vista-previa',
    conReglas(async (request, reply) => {
      const { formato } = esquemaVistaPrevia.parse(request.query);
      const pdf = await vistaPreviaPdf(request.usuario, esquemaVenta.parse(request.body), formato);
      return reply.type('application/pdf').send(pdf);
    }),
  );

  app.post(
    '/comprobantes',
    conReglas(async (request, reply) => {
      const clave = claveObligatoria(request);
      const { comprobante, repetido } = await emitirVenta(request.usuario, clave, esquemaVenta.parse(request.body));
      return reply.status(repetido ? 200 : 201).send(comprobante);
    }),
  );

  app.post(
    '/comprobantes/notas',
    conReglas(async (request, reply) => {
      const { comprobante, repetido } = await emitirNota(request.usuario, claveOpcional(request), esquemaNota.parse(request.body));
      return reply.status(repetido ? 200 : 201).send(comprobante);
    }),
  );

  app.get(
    '/comprobantes/:id',
    conReglas(async (request) => obtener(request.usuario, esquemaId.parse(request.params).id)),
  );

  app.post(
    '/comprobantes/:id/reenviar',
    conReglas(async (request) => reenviar(request.usuario, esquemaId.parse(request.params).id)),
  );

  app.post(
    '/comprobantes/:id/consultar',
    conReglas(async (request) => consultar(request.usuario, esquemaId.parse(request.params).id)),
  );

  app.post(
    '/comprobantes/:id/anular',
    { preHandler: requerirRol('admin') },
    conReglas(async (request) => anular(request.usuario, esquemaId.parse(request.params).id, esquemaAnular.parse(request.body).motivo)),
  );

  app.get(
    '/comprobantes/:id/archivo/:tipo',
    conReglas(async (request) => {
      const { id, tipo } = esquemaArchivo.parse(request.params);
      return urlArchivo(request.usuario, id, tipo);
    }),
  );
}
