import type { FastifyInstance, FastifyRequest } from 'fastify';
import { createRemoteJWKSet, decodeProtectedHeader, jwtVerify } from 'jose';
import type { JWTPayload } from 'jose';
import { entorno } from '../config/entorno.js';
import { pool } from '../db/pool.js';
import { ErrorApi } from './errores.js';

export type RolUsuario = 'admin' | 'cajero' | 'contador';

export type UsuarioAutenticado = {
  id: string;
  rol: RolUsuario;
  establecimiento_id: string | null;
};

declare module 'fastify' {
  interface FastifyRequest {
    usuario: UsuarioAutenticado;
  }
  interface FastifyContextConfig {
    publica?: boolean;
  }
}

const AUDIENCIA = 'authenticated';
const ALGORITMOS_ASIMETRICOS = ['RS256', 'ES256'];
const FORMATO_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const jwks = createRemoteJWKSet(new URL(entorno.SUPABASE_JWKS_URL));
const emisorEsperado = `${entorno.SUPABASE_URL}/auth/v1`;

const tokenInvalido = () => new ErrorApi(401, 'TOKEN_INVALIDO', 'La sesión no es válida o expiró.');

function extraerToken(request: FastifyRequest): string {
  const [esquema, token] = (request.headers.authorization ?? '').split(' ');
  if (esquema?.toLowerCase() !== 'bearer' || !token) {
    throw new ErrorApi(401, 'NO_AUTENTICADO', 'Falta el token de sesión.');
  }
  return token;
}

async function verificarToken(token: string): Promise<JWTPayload> {
  const opciones = { issuer: emisorEsperado, audience: AUDIENCIA };
  try {
    const { alg } = decodeProtectedHeader(token);
    if (alg === 'HS256') {
      if (!entorno.SUPABASE_JWT_SECRET) throw tokenInvalido();
      const secreto = new TextEncoder().encode(entorno.SUPABASE_JWT_SECRET);
      return (await jwtVerify(token, secreto, { ...opciones, algorithms: ['HS256'] })).payload;
    }
    return (await jwtVerify(token, jwks, { ...opciones, algorithms: ALGORITMOS_ASIMETRICOS })).payload;
  } catch {
    throw tokenInvalido();
  }
}

type PerfilActivo = { rol: RolUsuario; establecimiento_id: string | null; activo: boolean };

async function cargarPerfil(id: string): Promise<UsuarioAutenticado> {
  const { rows } = await pool.query<PerfilActivo>('select rol, establecimiento_id, activo from perfiles where id = $1', [id]);
  const perfil = rows[0];
  if (!perfil || !perfil.activo) {
    throw new ErrorApi(403, 'USUARIO_INACTIVO', 'Tu usuario no tiene acceso activo.');
  }
  return { id, rol: perfil.rol, establecimiento_id: perfil.establecimiento_id };
}

export function registrarAutenticacion(app: FastifyInstance) {
  app.decorateRequest('usuario', null as unknown as UsuarioAutenticado);
  app.addHook('onRequest', async (request) => {
    if (request.routeOptions.config?.publica || !request.routeOptions.url) return;
    const carga = await verificarToken(extraerToken(request));
    if (!carga.sub || !FORMATO_UUID.test(carga.sub)) throw tokenInvalido();
    request.usuario = await cargarPerfil(carga.sub);
  });
}

export function requerirRol(...roles: RolUsuario[]) {
  return async (request: FastifyRequest) => {
    if (!roles.includes(request.usuario.rol)) {
      throw new ErrorApi(403, 'PERMISO_DENEGADO', 'No tienes permiso para esta operación.');
    }
  };
}
