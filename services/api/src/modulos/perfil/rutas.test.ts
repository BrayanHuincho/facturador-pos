import multipart from '@fastify/multipart';
import Fastify, { type FastifyInstance } from 'fastify';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { detectarImagen } from './imagen.js';

const USUARIO = '11111111-1111-4111-8111-111111111111';

const { cliente, auditoria, upload, remove } = vi.hoisted(() => ({
  cliente: { query: vi.fn() },
  auditoria: vi.fn(),
  upload: vi.fn(),
  remove: vi.fn(),
}));

vi.mock('../../db/pool.js', () => ({ withTransaction: (fn: (c: unknown) => unknown) => fn(cliente), pool: { query: vi.fn() } }));
vi.mock('../../db/auditoria.js', () => ({ registrarAuditoria: auditoria }));
vi.mock('../../storage/archivos.js', () => ({ supabaseAdmin: { storage: { from: () => ({ upload, remove }) } } }));

import { ErrorApi } from '../../http/errores.js';
import { BYTES_MAXIMOS_FOTO, perfilRutas } from './rutas.js';

const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3]);
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2]);
const WEBP = Buffer.concat([Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WEBP'), Buffer.alloc(2)]);

async function crearApp(): Promise<FastifyInstance> {
  const app = Fastify();
  await app.register(multipart);
  app.decorateRequest('usuario', null as never);
  app.addHook('onRequest', async (request) => {
    (request as unknown as { usuario: unknown }).usuario = { id: USUARIO, rol: 'cajero', establecimiento_id: null };
  });
  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof ErrorApi) return reply.status(error.status).send({ codigo: error.codigo });
    return reply.status(422).send({ codigo: 'DATOS_INVALIDOS' });
  });
  await app.register(perfilRutas);
  return app;
}

function multiparte(contenido: Buffer) {
  const limite = '----limite';
  return {
    headers: { 'content-type': `multipart/form-data; boundary=${limite}` },
    payload: Buffer.concat([Buffer.from(`--${limite}\r\nContent-Disposition: form-data; name="archivo"; filename="a.png"\r\nContent-Type: application/octet-stream\r\n\r\n`), contenido, Buffer.from(`\r\n--${limite}--\r\n`)]),
  };
}

describe('detección de imágenes por contenido', () => {
  it('reconoce png, jpeg y webp', () => {
    expect(detectarImagen(PNG)?.extension).toBe('png');
    expect(detectarImagen(JPEG)?.extension).toBe('jpg');
    expect(detectarImagen(WEBP)?.extension).toBe('webp');
  });

  it('rechaza contenido que no es imagen aunque empiece parecido', () => {
    expect(detectarImagen(Buffer.from('<svg></svg>'))).toBeNull();
    expect(detectarImagen(Buffer.from('RIFFxxxxWAVE'))).toBeNull();
    expect(detectarImagen(Buffer.alloc(0))).toBeNull();
  });
});

describe('rutas de /perfil', () => {
  let app: FastifyInstance;

  beforeEach(async () => {
    vi.clearAllMocks();
    upload.mockResolvedValue({ error: null });
    remove.mockResolvedValue({ error: null });
    cliente.query.mockImplementation(async (sql: string) => {
      if (sql.includes('select foto_path')) return { rows: [{ foto_path: 'perfiles/viejo.png' }] };
      return { rows: [{ id: USUARIO, nombre: 'Ana', foto_path: 'perfiles/x.png' }] };
    });
    app = await crearApp();
  });

  it('cambia solo el nombre del propio usuario y audita', async () => {
    const r = await app.inject({ method: 'PATCH', url: '/perfil', payload: { nombre: '  Ana  ', rol: 'admin' } });
    expect(r.statusCode).toBe(200);
    expect(cliente.query.mock.calls[0]![1]).toEqual([USUARIO, 'Ana']);
    expect(cliente.query.mock.calls[0]![0]).not.toContain('rol =');
    expect(auditoria).toHaveBeenCalledWith(cliente, expect.objectContaining({ accion: 'PERFIL_ACTUALIZADO', entidadId: USUARIO }));
  });

  it('rechaza un nombre vacío', async () => {
    const r = await app.inject({ method: 'PATCH', url: '/perfil', payload: { nombre: '   ' } });
    expect(r.statusCode).toBe(422);
  });

  it('guarda la foto en la ruta del usuario y borra la anterior', async () => {
    const r = await app.inject({ method: 'POST', url: '/perfil/foto', ...multiparte(PNG) });
    expect(r.statusCode).toBe(200);
    expect(upload).toHaveBeenCalledWith(`perfiles/${USUARIO}.png`, expect.any(Buffer), expect.objectContaining({ contentType: 'image/png', upsert: true }));
    expect(remove).toHaveBeenCalledWith(['perfiles/viejo.png']);
    expect(auditoria).toHaveBeenCalledWith(cliente, expect.objectContaining({ accion: 'PERFIL_FOTO_ACTUALIZADA' }));
  });

  it('rechaza un archivo que no es imagen, sin importar su nombre', async () => {
    const r = await app.inject({ method: 'POST', url: '/perfil/foto', ...multiparte(Buffer.from('no soy imagen')) });
    expect(r.statusCode).toBe(415);
    expect(upload).not.toHaveBeenCalled();
  });

  it('rechaza una imagen de más de 5 MiB', async () => {
    const grande = Buffer.concat([PNG, Buffer.alloc(BYTES_MAXIMOS_FOTO + 1)]);
    const r = await app.inject({ method: 'POST', url: '/perfil/foto', ...multiparte(grande) });
    expect(r.statusCode).toBe(413);
    expect(upload).not.toHaveBeenCalled();
  });

  it('elimina la foto y limpia la columna', async () => {
    const r = await app.inject({ method: 'DELETE', url: '/perfil/foto' });
    expect(r.statusCode).toBe(200);
    expect(remove).toHaveBeenCalledWith(['perfiles/viejo.png']);
    expect(auditoria).toHaveBeenCalledWith(cliente, expect.objectContaining({ accion: 'PERFIL_FOTO_ELIMINADA' }));
  });
});
