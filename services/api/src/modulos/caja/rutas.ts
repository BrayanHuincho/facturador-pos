import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { pool, withTransaction } from '../../db/pool.js';
import { ErrorApi } from '../../http/errores.js';
import { calcularDiferencia, ESCALA_IMPORTE, usuarioFiltrado } from './calculos.js';
import {
  COLUMNAS_TURNO,
  calcularResumenTurno,
  registrarAuditoria,
  type TurnoCaja,
} from './repositorio.js';
import { identificador, importeNoNegativo, importePositivo, validar } from './validacion.js';

const CODIGO_VIOLACION_UNICA = '23505';

const esquemaApertura = z.object({ monto_apertura: importeNoNegativo });
const esquemaCierre = z.object({
  monto_contado: importeNoNegativo,
  observacion: z.string().trim().max(500).optional(),
});
const esquemaMovimiento = z.object({
  tipo: z.enum(['ingreso', 'egreso']),
  monto: importePositivo,
  concepto: z.string().trim().min(1).max(200),
});
const esquemaParametrosTurno = z.object({ id: identificador });

function turnoNoAbierto(): ErrorApi {
  return new ErrorApi(409, 'TURNO_NO_ABIERTO', 'No tienes un turno de caja abierto');
}

function esViolacionUnica(error: unknown): boolean {
  return typeof error === 'object' && error !== null && (error as { code?: unknown }).code === CODIGO_VIOLACION_UNICA;
}

export async function cajaRutas(app: FastifyInstance): Promise<void> {
  app.get('/caja/turno-actual', async (request) => {
    const { rows } = await pool.query<TurnoCaja>(
      `SELECT ${COLUMNAS_TURNO} FROM turnos_caja WHERE usuario_id = $1 AND estado = 'abierto'`,
      [request.usuario.id],
    );
    const turno = rows[0];
    if (!turno) return { turno: null, resumen: null };
    return { turno, resumen: await calcularResumenTurno(pool, turno.id, turno.monto_apertura) };
  });

  app.post('/caja/abrir', async (request, reply) => {
    const { monto_apertura } = validar(esquemaApertura, request.body);
    const { id: usuarioId, establecimiento_id: establecimientoId } = request.usuario;
    if (!establecimientoId) {
      throw new ErrorApi(409, 'USUARIO_SIN_ESTABLECIMIENTO', 'El usuario no tiene un establecimiento asignado');
    }
    try {
      const turno = await withTransaction(async (c) => {
        const { rows } = await c.query<TurnoCaja>(
          `INSERT INTO turnos_caja (establecimiento_id, usuario_id, estado, abierto_en, monto_apertura)
           VALUES ($1, $2, 'abierto', now(), $3)
           RETURNING ${COLUMNAS_TURNO}`,
          [establecimientoId, usuarioId, monto_apertura],
        );
        const creado = rows[0]!;
        await registrarAuditoria(c, {
          usuarioId,
          accion: 'caja.abrir',
          entidad: 'turnos_caja',
          entidadId: creado.id,
          detalle: { monto_apertura },
        });
        return creado;
      });
      return reply.status(201).send({ turno });
    } catch (error) {
      if (esViolacionUnica(error)) {
        throw new ErrorApi(409, 'TURNO_YA_ABIERTO', 'Ya tienes un turno de caja abierto');
      }
      throw error;
    }
  });

  app.post('/caja/cerrar', async (request) => {
    const { monto_contado, observacion } = validar(esquemaCierre, request.body);
    const usuarioId = request.usuario.id;
    return withTransaction(async (c) => {
      const abierto = await c.query<TurnoCaja>(
        `SELECT ${COLUMNAS_TURNO} FROM turnos_caja
          WHERE usuario_id = $1 AND estado = 'abierto'
          FOR UPDATE`,
        [usuarioId],
      );
      const turno = abierto.rows[0];
      if (!turno) throw turnoNoAbierto();

      const resumen = await calcularResumenTurno(c, turno.id, turno.monto_apertura);
      const diferencia = calcularDiferencia(monto_contado, resumen.monto_esperado).toFixed(ESCALA_IMPORTE);
      const cerrado = await c.query<TurnoCaja>(
        `UPDATE turnos_caja
            SET estado = 'cerrado', cerrado_en = now(), monto_esperado = $2, monto_contado = $3,
                diferencia = $4, observacion = $5, actualizado_en = now()
          WHERE id = $1
          RETURNING ${COLUMNAS_TURNO}`,
        [turno.id, resumen.monto_esperado, monto_contado, diferencia, observacion ?? null],
      );
      await registrarAuditoria(c, {
        usuarioId,
        accion: 'caja.cerrar',
        entidad: 'turnos_caja',
        entidadId: turno.id,
        detalle: { monto_esperado: resumen.monto_esperado, monto_contado, diferencia, observacion: observacion ?? null },
      });
      return { turno: cerrado.rows[0]!, resumen };
    });
  });

  app.post('/caja/movimientos', async (request, reply) => {
    const { tipo, monto, concepto } = validar(esquemaMovimiento, request.body);
    const usuarioId = request.usuario.id;
    const movimiento = await withTransaction(async (c) => {
      const abierto = await c.query<{ id: string }>(
        `SELECT id FROM turnos_caja WHERE usuario_id = $1 AND estado = 'abierto' FOR UPDATE`,
        [usuarioId],
      );
      const turno = abierto.rows[0];
      if (!turno) throw turnoNoAbierto();

      const { rows } = await c.query<{ id: string }>(
        `INSERT INTO movimientos_caja (turno_id, tipo, monto, concepto, usuario_id)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, turno_id, tipo, monto, concepto, usuario_id, creado_en`,
        [turno.id, tipo, monto, concepto, usuarioId],
      );
      const creado = rows[0]!;
      await registrarAuditoria(c, {
        usuarioId,
        accion: 'caja.movimiento',
        entidad: 'movimientos_caja',
        entidadId: creado.id,
        detalle: { turno_id: turno.id, tipo, monto, concepto },
      });
      return creado;
    });
    return reply.status(201).send({ movimiento });
  });

  app.get('/caja/turnos/:id/resumen', async (request) => {
    const { id } = validar(esquemaParametrosTurno, request.params);
    const { rows } = await pool.query<TurnoCaja>(
      `SELECT ${COLUMNAS_TURNO} FROM turnos_caja
        WHERE id = $1 AND ($2::uuid IS NULL OR usuario_id = $2::uuid)`,
      [id, usuarioFiltrado(request.usuario)],
    );
    const turno = rows[0];
    if (!turno) throw new ErrorApi(404, 'TURNO_NO_ENCONTRADO', 'Turno de caja no encontrado');

    const calculado = await calcularResumenTurno(pool, turno.id, turno.monto_apertura);
    return {
      turno,
      resumen: {
        ...calculado,
        monto_esperado: turno.monto_esperado ?? calculado.monto_esperado,
        monto_esperado_recalculado: calculado.monto_esperado,
      },
    };
  });
}
