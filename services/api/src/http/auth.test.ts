import type { FastifyInstance } from 'fastify';
import { SignJWT } from 'jose';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

const perfil = vi.hoisted(() => ({ fila: null as null | { rol: string; establecimiento_id: string | null; activo: boolean } }));

vi.mock('../db/pool.js', () => ({
  pool: { query: async () => ({ rows: perfil.fila ? [perfil.fila] : [] }) },
  withTransaction: async () => undefined,
}));

const { crearApp } = await import('./app.js');
const { requerirRol } = await import('./auth.js');

const ID = '11111111-1111-1111-1111-111111111111';

function firmar(secreto = process.env.SUPABASE_JWT_SECRET ?? '', emisor = `${process.env.SUPABASE_URL}/auth/v1`) {
  return new SignJWT({})
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(ID)
    .setIssuer(emisor)
    .setAudience('authenticated')
    .setExpirationTime('5m')
    .sign(new TextEncoder().encode(secreto));
}

let app: FastifyInstance;

beforeAll(async () => {
  app = await crearApp(async (api) => {
    api.get('/quien', async (request) => request.usuario);
    api.get('/admin', { preHandler: requerirRol('admin') }, async () => ({ ok: true }));
    api.get('/limitada', { config: { rateLimit: { max: 1, timeWindow: '1 minute' } } }, async () => ({ ok: true }));
  });
});

beforeEach(() => {
  perfil.fila = { rol: 'cajero', establecimiento_id: null, activo: true };
});

const pedir = async (url: string, token?: string) =>
  app.inject({ method: 'GET', url: `/api/v1${url}`, headers: token ? { authorization: `Bearer ${token}` } : {} });

describe('autenticación HTTP', () => {
  it('deja pública solo la salud', async () => {
    expect((await pedir('/salud')).statusCode).toBe(200);
    const respuesta = await pedir('/quien');
    expect(respuesta.statusCode).toBe(401);
    expect(respuesta.json().error.codigo).toBe('NO_AUTENTICADO');
  });

  it('acepta un token HS256 válido y carga el perfil', async () => {
    const respuesta = await pedir('/quien', await firmar());
    expect(respuesta.statusCode).toBe(200);
    expect(respuesta.json()).toEqual({ id: ID, rol: 'cajero', establecimiento_id: null });
  });

  it('rechaza firma o emisor incorrectos', async () => {
    expect((await pedir('/quien', await firmar('otro-secreto-con-longitud-suficiente-xx'))).statusCode).toBe(401);
    expect((await pedir('/quien', await firmar(undefined, 'http://otro/auth/v1'))).statusCode).toBe(401);
  });

  it('rechaza perfiles inactivos o inexistentes', async () => {
    perfil.fila = { rol: 'admin', establecimiento_id: null, activo: false };
    expect((await pedir('/quien', await firmar())).json().error.codigo).toBe('USUARIO_INACTIVO');
    perfil.fila = null;
    expect((await pedir('/quien', await firmar())).statusCode).toBe(403);
  });

  it('aplica requerirRol', async () => {
    expect((await pedir('/admin', await firmar())).json().error.codigo).toBe('PERMISO_DENEGADO');
    perfil.fila = { rol: 'admin', establecimiento_id: null, activo: true };
    expect((await pedir('/admin', await firmar())).statusCode).toBe(200);
  });

  it('responde el límite con el formato de error del contrato', async () => {
    const token = await firmar();
    await pedir('/limitada', token);
    const respuesta = await pedir('/limitada', token);
    expect(respuesta.statusCode).toBe(429);
    expect(respuesta.json().error.codigo).toBe('LIMITE_EXCEDIDO');
  });
});
