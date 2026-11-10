import { Decimal } from 'decimal.js';

export type Valor = Decimal.Value;
export { Decimal };

export const decimal = (valor: Valor | null | undefined): Decimal => new Decimal(valor ?? 0);
export const CERO = decimal(0);
export const IGV_POR_DEFECTO = 18;
export const ICBPER_POR_UNIDAD = '0.50';

export function redondear(valor: Decimal, decimales = 2): Decimal {
  return valor.toDecimalPlaces(decimales, Decimal.ROUND_HALF_UP);
}
