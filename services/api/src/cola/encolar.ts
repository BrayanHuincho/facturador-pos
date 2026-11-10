import type { PoolClient } from 'pg';

export type TipoTrabajo =
  | 'enviar_comprobante'
  | 'consultar_ticket'
  | 'enviar_resumen'
  | 'enviar_baja'
  | 'enviar_guia'
  | 'consultar_guia'
  | 'generar_resumen_diario';

export async function encolar(c: PoolClient, tipo: TipoTrabajo, payload: Record<string, unknown>, ejecutarEn?: Date): Promise<string> {
  const { rows } = await c.query<{ id: string }>(
    `insert into trabajos (tipo, payload, ejecutar_en) values ($1, $2::jsonb, coalesce($3::timestamptz, now())) returning id`,
    [tipo, JSON.stringify(payload), ejecutarEn ?? null],
  );
  return rows[0].id;
}
