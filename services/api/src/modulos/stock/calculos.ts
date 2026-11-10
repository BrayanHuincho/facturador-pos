import { Decimal } from 'decimal.js';

export function calcularNuevoStock(actual: Decimal.Value, ajuste: Decimal.Value): Decimal {
  return new Decimal(actual).plus(ajuste);
}

export function ajusteDejaStockInvalido(ajuste: Decimal.Value, nuevoStock: Decimal.Value): boolean {
  return new Decimal(ajuste).isNegative() && new Decimal(nuevoStock).isNegative();
}
