import { describe, expect, it } from 'vitest';
import { ajusteDejaStockInvalido, calcularNuevoStock } from './calculos.js';

describe('calcularNuevoStock', () => {
  it('aplica ajustes con signo y cuatro decimales', () => {
    expect(calcularNuevoStock('10.5000', '-0.2500').toFixed(4)).toBe('10.2500');
    expect(calcularNuevoStock('0.1', '0.2').toFixed(4)).toBe('0.3000');
  });
});

describe('ajusteDejaStockInvalido', () => {
  it('rechaza una salida que deja stock negativo', () => {
    expect(ajusteDejaStockInvalido('-5', '-1')).toBe(true);
  });

  it('acepta una salida que deja el stock en cero', () => {
    expect(ajusteDejaStockInvalido('-5', calcularNuevoStock('5', '-5'))).toBe(false);
  });

  it('acepta una entrada aunque el stock siga negativo', () => {
    expect(ajusteDejaStockInvalido('2', '-1')).toBe(false);
  });
});
