import type { PoolClient } from 'pg';
import { describe, expect, it, vi } from 'vitest';
import { revertirAnulaciones } from './servicio.js';

function clienteFalso(tipo: string, estado = 'por_anular') {
  const query = vi.fn(async (texto: string, _valores?: unknown[]) => {
    if (/for update/.test(texto)) return { rows: estado === 'por_anular' ? [{ tipo, establecimiento_id: 'e1', usuario_id: 'u1' }] : [] };
    if (/FROM comprobante_items/i.test(texto)) return { rows: [{ producto_id: 'p1', cantidad: '2.0000' }, { producto_id: 'p1', cantidad: '1.0000' }, { producto_id: 'p2', cantidad: '5.0000' }] };
    if (/from productos/i.test(texto)) return { rows: [{ id: 'p1' }] };
    return { rows: [] };
  });
  return { c: { query } as unknown as PoolClient, query };
}

const sentencias = (query: ReturnType<typeof clienteFalso>['query'], patron: RegExp) => query.mock.calls.filter(([texto]) => patron.test(texto));

describe('anulación rechazada por SUNAT', () => {
  it('vuelve al estado aceptado y revierte la reposición de stock', async () => {
    const { c, query } = clienteFalso('01');
    await revertirAnulaciones(c, ['x1'], 'Anulación no aceptada');
    expect(sentencias(query, /update comprobantes/i)[0][0]).toMatch(/then 'observado' else 'aceptado'/);
    const movimiento = sentencias(query, /INSERT INTO movimientos_stock/i);
    expect(movimiento).toHaveLength(1);
    expect(movimiento[0][1]).toEqual(['p1', 'e1', 'venta', '-3.0000', 'x1', 'u1']);
  });

  it('una nota no repuso stock y no lo mueve', async () => {
    const { c, query } = clienteFalso('07');
    await revertirAnulaciones(c, ['x1'], 'n');
    expect(sentencias(query, /update comprobantes/i)).toHaveLength(1);
    expect(sentencias(query, /movimientos_stock/i)).toHaveLength(0);
  });

  it('si ya no está por anular no hace nada', async () => {
    const { c, query } = clienteFalso('01', 'aceptado');
    await revertirAnulaciones(c, ['x1'], 'n');
    expect(query).toHaveBeenCalledTimes(1);
  });
});
