import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { registrarAuditoria } from '../../db/auditoria.js';
import { withTransaction } from '../../db/pool.js';
import { ErrorApi } from '../../http/errores.js';
import { supabaseAdmin } from '../../storage/archivos.js';
import { detectarImagen } from './imagen.js';

export const BYTES_MAXIMOS_FOTO = 5 * 1024 * 1024;
const BUCKET_IMAGENES = 'imagenes';
const COLUMNAS_PERFIL = 'id, nombre, rol, establecimiento_id, activo, foto_path, actualizado_en';

const esquemaPerfil = z.object({ nombre: z.string().trim().min(1).max(200) });

type FilaPerfil = { id: string; nombre: string; rol: string; establecimiento_id: string | null; activo: boolean; foto_path: string | null; actualizado_en: Date };

async function leerFoto(request: FastifyRequest): Promise<Buffer> {
  try {
    const archivo = await request.file({ limits: { fileSize: BYTES_MAXIMOS_FOTO, files: 1 } });
    if (!archivo) throw new ErrorApi(400, 'ARCHIVO_REQUERIDO', 'Adjunta una imagen.');
    return await archivo.toBuffer();
  } catch (error) {
    if (error instanceof ErrorApi) throw error;
    if ((error as { statusCode?: number }).statusCode === 413) {
      throw new ErrorApi(413, 'IMAGEN_MUY_GRANDE', 'La imagen supera los 5 MB permitidos.');
    }
    throw new ErrorApi(400, 'ARCHIVO_INVALIDO', 'No se pudo leer el archivo enviado.');
  }
}

async function borrarFotoAnterior(ruta: string | null | undefined, nueva: string | null): Promise<void> {
  if (!ruta || ruta === nueva) return;
  await supabaseAdmin.storage.from(BUCKET_IMAGENES).remove([ruta]).catch(() => undefined);
}

async function guardarFoto(usuarioId: string, ruta: string | null, accion: string, detalle: Record<string, unknown>) {
  const { perfil, anterior } = await withTransaction(async (c) => {
    const actual = await c.query<{ foto_path: string | null }>('select foto_path from perfiles where id = $1 for update', [usuarioId]);
    if (!actual.rows[0]) throw new ErrorApi(404, 'USUARIO_NO_ENCONTRADO', 'El usuario no existe.');
    const { rows } = await c.query<FilaPerfil>(`update perfiles set foto_path = $2, actualizado_en = now() where id = $1 returning ${COLUMNAS_PERFIL}`, [usuarioId, ruta]);
    await registrarAuditoria(c, { usuarioId, accion, entidad: 'perfiles', entidadId: usuarioId, detalle });
    return { perfil: rows[0] as FilaPerfil, anterior: actual.rows[0].foto_path };
  });
  await borrarFotoAnterior(anterior, ruta);
  return perfil;
}

export async function perfilRutas(app: FastifyInstance) {
  app.patch('/perfil', async (request) => {
    const { nombre } = esquemaPerfil.parse(request.body);
    const usuarioId = request.usuario.id;
    return withTransaction(async (c) => {
      const { rows } = await c.query<FilaPerfil>(`update perfiles set nombre = $2, actualizado_en = now() where id = $1 returning ${COLUMNAS_PERFIL}`, [usuarioId, nombre]);
      if (!rows[0]) throw new ErrorApi(404, 'USUARIO_NO_ENCONTRADO', 'El usuario no existe.');
      await registrarAuditoria(c, { usuarioId, accion: 'PERFIL_ACTUALIZADO', entidad: 'perfiles', entidadId: usuarioId, detalle: { campos: ['nombre'] } });
      return rows[0];
    });
  });

  app.post('/perfil/foto', async (request) => {
    const contenido = await leerFoto(request);
    const tipo = detectarImagen(contenido);
    if (!tipo) throw new ErrorApi(415, 'IMAGEN_NO_VALIDA', 'La imagen debe ser PNG, JPEG o WebP.');
    const usuarioId = request.usuario.id;
    const ruta = `perfiles/${usuarioId}.${tipo.extension}`;
    const { error } = await supabaseAdmin.storage.from(BUCKET_IMAGENES).upload(ruta, contenido, { contentType: tipo.mime, upsert: true });
    if (error) throw new ErrorApi(502, 'ALMACENAMIENTO_NO_DISPONIBLE', 'No se pudo guardar la imagen.');
    return guardarFoto(usuarioId, ruta, 'PERFIL_FOTO_ACTUALIZADA', { ruta, bytes: contenido.length, tipo: tipo.mime });
  });

  app.delete('/perfil/foto', async (request) => guardarFoto(request.usuario.id, null, 'PERFIL_FOTO_ELIMINADA', {}));
}
