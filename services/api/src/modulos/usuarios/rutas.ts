import type { FastifyInstance } from 'fastify';
import type { PoolClient } from 'pg';
import { z } from 'zod';
import { registrarAuditoria } from '../../db/auditoria.js';
import { pool, withTransaction } from '../../db/pool.js';
import { requerirRol } from '../../http/auth.js';
import { ErrorApi } from '../../http/errores.js';
import { supabaseAdmin } from '../../storage/archivos.js';

const rol = z.enum(['admin', 'cajero', 'contador']);
const clave = z.string().min(8).max(72);
const USUARIOS_POR_PAGINA = 1000;

const esquemaCrear = z.object({
  correo: z.email(),
  clave,
  nombre: z.string().trim().min(1).max(200),
  rol,
  establecimiento_id: z.uuid().nullable().optional(),
});

const esquemaActualizar = z.object({
  nombre: z.string().trim().min(1).max(200).optional(),
  rol: rol.optional(),
  establecimiento_id: z.uuid().nullable().optional(),
  activo: z.boolean().optional(),
  clave: clave.optional(),
});

const parametrosId = z.object({ id: z.uuid() });

type FilaPerfil = { id: string; nombre: string; rol: string; establecimiento_id: string | null; activo: boolean };

const COLUMNAS_PERFIL = 'id, nombre, rol, establecimiento_id, activo';

async function correosPorUsuario(): Promise<Map<string, string | null>> {
  const correos = new Map<string, string | null>();
  for (let pagina = 1; ; pagina += 1) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page: pagina, perPage: USUARIOS_POR_PAGINA });
    if (error) throw new ErrorApi(502, 'AUTH_NO_DISPONIBLE', 'No se pudo consultar los usuarios.');
    for (const usuario of data.users) correos.set(usuario.id, usuario.email ?? null);
    if (data.users.length < USUARIOS_POR_PAGINA) return correos;
  }
}

async function establecimientoPrincipal(c: PoolClient): Promise<string | null> {
  const { rows } = await c.query<{ id: string }>("select id from establecimientos where activo order by (codigo = '0000') desc, creado_en limit 1");
  return rows[0]?.id ?? null;
}

async function protegerUltimoAdmin(c: PoolClient, id: string, datos: z.infer<typeof esquemaActualizar>) {
  const dejaDeSerAdmin = (datos.rol !== undefined && datos.rol !== 'admin') || datos.activo === false;
  if (!dejaDeSerAdmin) return;
  const { rows } = await c.query<{ id: string }>("select id from perfiles where rol = 'admin' and activo for update");
  const otrosAdmins = rows.filter((fila) => fila.id !== id);
  if (rows.length !== otrosAdmins.length && otrosAdmins.length === 0) {
    throw new ErrorApi(409, 'ULTIMO_ADMIN', 'Debe quedar al menos un administrador activo.');
  }
}

export async function usuariosRutas(app: FastifyInstance) {
  const soloAdmin = { preHandler: requerirRol('admin') };

  app.get('/usuarios', soloAdmin, async () => {
    const [{ rows }, correos] = await Promise.all([pool.query<FilaPerfil>(`select ${COLUMNAS_PERFIL} from perfiles order by nombre`), correosPorUsuario()]);
    return rows.map((perfil) => ({ ...perfil, correo: correos.get(perfil.id) ?? null }));
  });

  app.post('/usuarios', soloAdmin, async (request, reply) => {
    const datos = esquemaCrear.parse(request.body);
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email: datos.correo,
      password: datos.clave,
      email_confirm: true,
      user_metadata: { nombre: datos.nombre },
      app_metadata: { rol: datos.rol },
    });
    if (error || !data.user) {
      const yaExiste = error?.status === 422 || error?.status === 409;
      throw yaExiste
        ? new ErrorApi(409, 'CORREO_EN_USO', 'No se pudo crear el usuario: el correo ya está registrado o la clave no es aceptada.')
        : new ErrorApi(502, 'AUTH_NO_DISPONIBLE', 'No se pudo crear el usuario.');
    }
    const id = data.user.id;
    try {
      const perfil = await withTransaction(async (c) => {
        const establecimiento = datos.establecimiento_id ?? (await establecimientoPrincipal(c));
        const { rows } = await c.query<FilaPerfil>(
          `insert into perfiles (id, nombre, rol, establecimiento_id, activo) values ($1, $2, $3, $4, true)
           on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, establecimiento_id = excluded.establecimiento_id, activo = true, actualizado_en = now()
           returning ${COLUMNAS_PERFIL}`,
          [id, datos.nombre, datos.rol, establecimiento],
        );
        await registrarAuditoria(c, {
          usuarioId: request.usuario.id,
          accion: 'USUARIO_CREADO',
          entidad: 'perfiles',
          entidadId: id,
          detalle: { correo: datos.correo, rol: datos.rol },
        });
        return rows[0] as FilaPerfil;
      });
      return reply.status(201).send({ ...perfil, correo: datos.correo });
    } catch (errorPerfil) {
      await supabaseAdmin.auth.admin.deleteUser(id).catch(() => undefined);
      throw errorPerfil;
    }
  });

  app.patch('/usuarios/:id', soloAdmin, async (request) => {
    const { id } = parametrosId.parse(request.params);
    const datos = esquemaActualizar.parse(request.body);
    const { clave: nuevaClave, ...campos } = datos;
    const perfil = await withTransaction(async (c) => {
      await protegerUltimoAdmin(c, id, datos);
      const claves = Object.keys(campos).filter((campo) => campos[campo as keyof typeof campos] !== undefined);
      const asignaciones = claves.map((campo, indice) => `${campo} = $${indice + 2}`);
      const { rows } = await c.query<FilaPerfil>(
        `update perfiles set ${[...asignaciones, 'actualizado_en = now()'].join(', ')} where id = $1 returning ${COLUMNAS_PERFIL}`,
        [id, ...claves.map((campo) => campos[campo as keyof typeof campos])],
      );
      if (!rows[0]) throw new ErrorApi(404, 'USUARIO_NO_ENCONTRADO', 'El usuario no existe.');
      if (nuevaClave !== undefined) {
        const { error } = await supabaseAdmin.auth.admin.updateUserById(id, { password: nuevaClave });
        if (error) throw new ErrorApi(502, 'AUTH_NO_DISPONIBLE', 'No se pudo cambiar la clave.');
      }
      await registrarAuditoria(c, {
        usuarioId: request.usuario.id,
        accion: 'USUARIO_ACTUALIZADO',
        entidad: 'perfiles',
        entidadId: id,
        detalle: { campos: claves, clave_cambiada: nuevaClave !== undefined },
      });
      return rows[0];
    });
    return perfil;
  });
}
