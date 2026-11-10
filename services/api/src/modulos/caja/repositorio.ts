import type { PoolClient } from 'pg';
import { construirResumenTurno, type ResumenTurno } from './calculos.js';

export type Consultor = Pick<PoolClient, 'query'>;

export const TIPOS_CON_MOVIMIENTO_DE_PAGO = ['01', '03', 'NV', '07'];
export const SIGNO_NOTA_CREDITO_SQL = "CASE WHEN c.tipo::text = '07' THEN -1 ELSE 1 END";
export const FACTOR_CAMBIO_SQL = "CASE WHEN c.moneda = 'PEN' THEN 1 ELSE COALESCE(c.tipo_cambio, 1) END";

const ESTADOS_ANULADOS = ['anulado', 'por_anular'];

export const COLUMNAS_TURNO = `id, establecimiento_id, usuario_id, estado, abierto_en, cerrado_en,
  monto_apertura, monto_esperado, monto_contado, diferencia, observacion`;

export interface TurnoCaja {
  id: string;
  establecimiento_id: string;
  usuario_id: string;
  estado: 'abierto' | 'cerrado';
  abierto_en: Date;
  cerrado_en: Date | null;
  monto_apertura: string;
  monto_esperado: string | null;
  monto_contado: string | null;
  diferencia: string | null;
  observacion: string | null;
}

export async function calcularResumenTurno(
  db: Consultor,
  turnoId: string,
  montoApertura: string,
): Promise<ResumenTurno> {
  const pagos = await db.query<{ medio: string; total: string }>(
    `SELECT p.medio::text AS medio,
            SUM(${SIGNO_NOTA_CREDITO_SQL} * ROUND(p.monto * ${FACTOR_CAMBIO_SQL}, 2))::text AS total
       FROM pagos p
       JOIN comprobantes c ON c.id = p.comprobante_id
      WHERE c.turno_id = $1
        AND c.tipo::text = ANY($2::text[])
        AND c.estado::text <> ALL($3::text[])
      GROUP BY p.medio
      ORDER BY p.medio`,
    [turnoId, TIPOS_CON_MOVIMIENTO_DE_PAGO, ESTADOS_ANULADOS],
  );
  const movimientos = await db.query<{ ingresos: string; egresos: string }>(
    `SELECT COALESCE(SUM(monto) FILTER (WHERE tipo::text = 'ingreso'), 0)::text AS ingresos,
            COALESCE(SUM(monto) FILTER (WHERE tipo::text = 'egreso'), 0)::text AS egresos
       FROM movimientos_caja
      WHERE turno_id = $1`,
    [turnoId],
  );
  return construirResumenTurno({
    apertura: montoApertura,
    pagosPorMedio: pagos.rows,
    ingresos: movimientos.rows[0]?.ingresos ?? '0',
    egresos: movimientos.rows[0]?.egresos ?? '0',
  });
}

export async function registrarAuditoria(
  c: Consultor,
  entrada: { usuarioId: string; accion: string; entidad: string; entidadId: string; detalle: unknown },
): Promise<void> {
  await c.query(
    `INSERT INTO auditoria (usuario_id, accion, entidad, entidad_id, detalle)
     VALUES ($1, $2, $3, $4, $5::jsonb)`,
    [entrada.usuarioId, entrada.accion, entrada.entidad, entrada.entidadId, JSON.stringify(entrada.detalle)],
  );
}
