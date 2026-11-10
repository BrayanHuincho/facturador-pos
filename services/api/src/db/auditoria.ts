import type { PoolClient } from 'pg';

export type EntradaAuditoria = {
  usuarioId: string;
  accion: string;
  entidad: string;
  entidadId?: string | null;
  detalle?: Record<string, unknown>;
};

export async function registrarAuditoria(c: PoolClient, entrada: EntradaAuditoria): Promise<void> {
  await c.query('insert into auditoria (usuario_id, accion, entidad, entidad_id, detalle) values ($1, $2, $3, $4, $5::jsonb)', [
    entrada.usuarioId,
    entrada.accion,
    entrada.entidad,
    entrada.entidadId ?? null,
    JSON.stringify(entrada.detalle ?? {}),
  ]);
}
