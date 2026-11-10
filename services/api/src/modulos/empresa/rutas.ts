import type { FastifyInstance } from 'fastify';
import type { PoolClient } from 'pg';
import { z } from 'zod';
import { registrarAuditoria } from '../../db/auditoria.js';
import { pool, withTransaction } from '../../db/pool.js';
import { requerirRol } from '../../http/auth.js';
import { ErrorApi } from '../../http/errores.js';
import { rucValido } from '../consultas/documento.js';

export const PLANTILLAS_PDF = ['clasica', 'moderna', 'minimalista', 'ejecutiva', 'compacta'] as const;

const MEDIOS_PAGO_CONFIGURABLES = ['efectivo', 'yape', 'plin', 'transferencia', 'tarjeta', 'deposito'] as const;

const SERIES_POR_DEFECTO: ReadonlyArray<readonly [string, string]> = [
  ['01', 'F001'],
  ['03', 'B001'],
  ['07', 'FC01'],
  ['07', 'BC01'],
  ['08', 'FD01'],
  ['08', 'BD01'],
  ['09', 'T001'],
  ['NV', 'NV01'],
];

const textoOpcionalNulo = (maximo: number) => z.string().trim().max(maximo).nullable().optional();
const ubigeo = z.string().regex(/^\d{6}$/);
const ruc = z.string().refine(rucValido, 'El RUC no es válido.');

const camposEmpresa = {
  nombre_comercial: textoOpcionalNulo(200),
  ubigeo: ubigeo.nullable().optional(),
  departamento: textoOpcionalNulo(100),
  provincia: textoOpcionalNulo(100),
  distrito: textoOpcionalNulo(100),
  direccion: textoOpcionalNulo(300),
  telefono: textoOpcionalNulo(30),
  correo: z.email().nullable().optional(),
  logo_path: textoOpcionalNulo(500),
  igv_porcentaje: z
    .union([z.string().regex(/^\d{1,2}(\.\d{1,2})?$/), z.number().min(0).max(99.99)])
    .transform(String)
    .optional(),
  precios_incluyen_igv: z.boolean().optional(),
  plantilla_pdf: z.enum(PLANTILLAS_PDF).optional(),
  modulos: z.strictObject({ caja: z.boolean(), guias: z.boolean(), reportes: z.boolean(), nota_venta: z.boolean() }).optional(),
  medios_pago: z.array(z.enum(MEDIOS_PAGO_CONFIGURABLES)).min(1).optional(),
  qr_yape_path: textoOpcionalNulo(500),
  qr_plin_path: textoOpcionalNulo(500),
};

const esquemaActualizar = z.object({
  ruc: ruc.optional(),
  razon_social: z.string().trim().min(1).max(300).optional(),
  ...camposEmpresa,
});

const esquemaInicial = z.object({
  empresa: z.object({ ruc, razon_social: z.string().trim().min(1).max(300), ...camposEmpresa }),
  establecimiento: z.object({
    nombre: z.string().trim().min(1).max(200),
    codigo: z.string().regex(/^\d{4}$/).default('0000'),
    direccion: textoOpcionalNulo(300),
    ubigeo: ubigeo.nullable().optional(),
  }),
});

const esquemaEstablecimiento = z.object({
  nombre: z.string().trim().min(1).max(200).optional(),
  direccion: textoOpcionalNulo(300),
  ubigeo: ubigeo.nullable().optional(),
});
const esquemaIdEstablecimiento = z.object({ id: z.uuid() });

type FilaEmpresa = Record<string, unknown> & { ruc: string | null; configurada: boolean };

async function actualizarFilaEmpresa(c: PoolClient, datos: Record<string, unknown>, extraSql = ''): Promise<FilaEmpresa> {
  const claves = Object.keys(datos).filter((clave) => datos[clave] !== undefined);
  const asignaciones = claves.map((clave, indice) => `${clave} = $${indice + 1}`);
  const sets = [...asignaciones, 'actualizado_en = now()', ...(extraSql ? [extraSql] : [])].join(', ');
  const { rows } = await c.query<FilaEmpresa>(`update empresa set ${sets} where id = 1 returning *`, claves.map((clave) => datos[clave]));
  return rows[0] as FilaEmpresa;
}

export async function empresaRutas(app: FastifyInstance) {
  const soloAdmin = { preHandler: requerirRol('admin') };

  app.get('/empresa', async () => {
    const { rows } = await pool.query('select * from empresa where id = 1');
    return rows[0] ?? { id: 1, configurada: false };
  });

  app.put('/empresa', soloAdmin, async (request) => {
    const datos = esquemaActualizar.parse(request.body);
    return withTransaction(async (c) => {
      const configuracion = await c.query<{ entorno: string }>('select entorno from configuracion_sunat where id = 1 for update');
      const actual = await c.query<FilaEmpresa>('select * from empresa where id = 1 for update');
      const rucAnterior = actual.rows[0]?.ruc ?? null;
      const cambiaRuc = datos.ruc !== undefined && datos.ruc !== rucAnterior;
      if (cambiaRuc && configuracion.rows[0]?.entorno === 'produccion') {
        throw new ErrorApi(409, 'RUC_BLOQUEADO_EN_PRODUCCION', 'No se puede cambiar el RUC en producción: vuelve primero a beta.');
      }
      const actualizada = await actualizarFilaEmpresa(c, datos);
      await registrarAuditoria(c, {
        usuarioId: request.usuario.id,
        accion: 'EMPRESA_ACTUALIZADA',
        entidad: 'empresa',
        detalle: { campos: Object.keys(datos), ...(cambiaRuc ? { ruc_antes: rucAnterior, ruc_despues: datos.ruc } : {}) },
      });
      return actualizada;
    });
  });

  app.patch('/establecimientos/:id', soloAdmin, async (request) => {
    const { id } = esquemaIdEstablecimiento.parse(request.params);
    const datos = esquemaEstablecimiento.parse(request.body);
    const claves = Object.keys(datos).filter((clave) => datos[clave as keyof typeof datos] !== undefined);
    return withTransaction(async (c) => {
      const asignaciones = [...claves.map((clave, indice) => `${clave} = $${indice + 2}`), 'actualizado_en = now()'].join(', ');
      const { rows } = await c.query(`update establecimientos set ${asignaciones} where id = $1 returning *`, [id, ...claves.map((clave) => datos[clave as keyof typeof datos])]);
      if (!rows[0]) throw new ErrorApi(404, 'ESTABLECIMIENTO_NO_ENCONTRADO', 'Establecimiento no encontrado.');
      await registrarAuditoria(c, {
        usuarioId: request.usuario.id,
        accion: 'ESTABLECIMIENTO_ACTUALIZADO',
        entidad: 'establecimientos',
        entidadId: id,
        detalle: { campos: claves },
      });
      return rows[0];
    });
  });

  app.post('/configuracion/inicial', soloAdmin, async (request, reply) => {
    const { empresa, establecimiento } = esquemaInicial.parse(request.body);
    const resultado = await withTransaction(async (c) => {
      const actual = await c.query<FilaEmpresa>('select configurada from empresa where id = 1 for update');
      if (actual.rows[0]?.configurada) {
        throw new ErrorApi(409, 'YA_CONFIGURADA', 'La empresa ya fue configurada.');
      }
      const filaEmpresa = await actualizarFilaEmpresa(c, empresa, 'configurada = true');
      const { rows } = await c.query<{ id: string }>(
        'insert into establecimientos (codigo, nombre, direccion, ubigeo) values ($1, $2, $3, $4) returning *',
        [establecimiento.codigo, establecimiento.nombre, establecimiento.direccion ?? filaEmpresa.direccion ?? null, establecimiento.ubigeo ?? filaEmpresa.ubigeo ?? null],
      );
      const principal = rows[0] as { id: string };
      for (const [tipo, serie] of SERIES_POR_DEFECTO) {
        await c.query('insert into series (establecimiento_id, tipo, serie) values ($1, $2, $3) on conflict (tipo, serie) do nothing', [principal.id, tipo, serie]);
      }
      await c.query('update perfiles set establecimiento_id = $1, actualizado_en = now() where id = $2 and establecimiento_id is null', [principal.id, request.usuario.id]);
      await registrarAuditoria(c, {
        usuarioId: request.usuario.id,
        accion: 'EMPRESA_CONFIGURACION_INICIAL',
        entidad: 'empresa',
        detalle: { ruc: empresa.ruc, establecimiento_id: principal.id },
      });
      return { empresa: filaEmpresa, establecimiento: principal };
    });
    return reply.status(201).send(resultado);
  });
}
