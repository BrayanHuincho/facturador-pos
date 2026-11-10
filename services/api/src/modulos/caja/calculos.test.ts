import { describe, expect, it } from 'vitest';
import {
  calcularDiferencia,
  calcularEfectivoEsperado,
  construirResumenTurno,
  usuarioFiltrado,
} from './calculos.js';

describe('calcularEfectivoEsperado', () => {
  it('suma apertura, ventas e ingresos y resta egresos', () => {
    const esperado = calcularEfectivoEsperado({
      apertura: '100.00',
      ventasEfectivo: '230.00',
      ingresos: '30.00',
      egresos: '10.25',
    });
    expect(esperado.toFixed(2)).toBe('349.75');
  });

  it('descuenta devoluciones cuando las ventas netas son negativas', () => {
    const esperado = calcularEfectivoEsperado({
      apertura: '100.00',
      ventasEfectivo: '-40.00',
      ingresos: '0',
      egresos: '0',
    });
    expect(esperado.toFixed(2)).toBe('60.00');
  });

  it('no arrastra error binario', () => {
    const esperado = calcularEfectivoEsperado({
      apertura: '0.10',
      ventasEfectivo: '0.20',
      ingresos: '0',
      egresos: '0',
    });
    expect(esperado.toFixed(2)).toBe('0.30');
  });
});

describe('calcularDiferencia', () => {
  it('es negativa con faltante y positiva con sobrante', () => {
    expect(calcularDiferencia('90.00', '100.00').toFixed(2)).toBe('-10.00');
    expect(calcularDiferencia('100.50', '100.00').toFixed(2)).toBe('0.50');
  });
});

describe('construirResumenTurno', () => {
  it('desglosa por medio y solo el efectivo afecta el esperado', () => {
    const resumen = construirResumenTurno({
      apertura: '50',
      pagosPorMedio: [
        { medio: 'efectivo', total: '100.00' },
        { medio: 'tarjeta', total: '80.00' },
      ],
      ingresos: '5',
      egresos: '15',
    });
    expect(resumen).toEqual({
      monto_apertura: '50.00',
      ventas_efectivo: '100.00',
      ingresos: '5.00',
      egresos: '15.00',
      monto_esperado: '140.00',
      total_ventas: '180.00',
      por_medio: [
        { medio: 'efectivo', total: '100.00' },
        { medio: 'tarjeta', total: '80.00' },
      ],
    });
  });

  it('funciona sin ventas', () => {
    const resumen = construirResumenTurno({ apertura: '10', pagosPorMedio: [], ingresos: '0', egresos: '0' });
    expect(resumen.monto_esperado).toBe('10.00');
    expect(resumen.por_medio).toEqual([]);
  });
});

describe('usuarioFiltrado', () => {
  it('limita al cajero y a cualquier rol desconocido', () => {
    expect(usuarioFiltrado({ id: 'u1', rol: 'cajero' })).toBe('u1');
    expect(usuarioFiltrado({ id: 'u1', rol: 'otro' })).toBe('u1');
  });

  it('no limita a admin ni contador', () => {
    expect(usuarioFiltrado({ id: 'u1', rol: 'admin' })).toBeNull();
    expect(usuarioFiltrado({ id: 'u1', rol: 'contador' })).toBeNull();
  });
});
