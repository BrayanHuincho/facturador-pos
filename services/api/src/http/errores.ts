import type { FastifyError, FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { ZodError } from 'zod';

export class ErrorApi extends Error {
  constructor(
    readonly status: number,
    readonly codigo: string,
    mensaje: string,
    readonly detalles?: unknown,
  ) {
    super(mensaje);
    this.name = 'ErrorApi';
  }
}

function responder(reply: FastifyReply, status: number, codigo: string, mensaje: string, detalles?: unknown) {
  return reply.status(status).send({ error: { codigo, mensaje, detalles: detalles ?? {} } });
}

const ERRORES_POSTGRES: Record<string, { status: number; codigo: string; mensaje: string }> = {
  '23505': { status: 409, codigo: 'CONFLICTO', mensaje: 'El registro ya existe.' },
  '23503': { status: 400, codigo: 'REFERENCIA_INVALIDA', mensaje: 'El registro relacionado no existe.' },
};

export function manejadorErrores(error: FastifyError | Error, request: FastifyRequest, reply: FastifyReply) {
  if (error instanceof ErrorApi) {
    return responder(reply, error.status, error.codigo, error.message, error.detalles);
  }
  if (error instanceof ZodError) {
    const detalles = error.issues.map((problema) => ({ campo: problema.path.join('.'), mensaje: problema.message }));
    return responder(reply, 400, 'VALIDACION', 'Los datos enviados no son válidos.', detalles);
  }
  const conocido = ERRORES_POSTGRES[(error as { code?: string }).code ?? ''];
  if (conocido) {
    return responder(reply, conocido.status, conocido.codigo, conocido.mensaje);
  }
  const status = (error as FastifyError).statusCode;
  if (status && status >= 400 && status < 500) {
    return responder(reply, status, (error as FastifyError).code ?? 'SOLICITUD_INVALIDA', error.message);
  }
  request.log.error({ err: error }, 'Error no controlado');
  return responder(reply, 500, 'ERROR_INTERNO', 'Ocurrió un error inesperado.');
}

export function registrarErrores(app: FastifyInstance) {
  app.setErrorHandler(manejadorErrores);
  app.setNotFoundHandler((_request, reply) => responder(reply, 404, 'NO_ENCONTRADO', 'Ruta no encontrada.'));
}
