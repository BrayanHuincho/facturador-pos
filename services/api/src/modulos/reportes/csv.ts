import { Decimal } from 'decimal.js';
import { ESCALA_IMPORTE } from '../caja/calculos.js';

export type CeldaCsv = string | number | Decimal | null | undefined;

const INICIO_FORMULA = /^[\s\u0000-\u001f]*[=+\-@＝＋－＠]|^[\t\r\n]/;
const REQUIERE_COMILLAS = /[",;\r\n]/;
const BOM_UTF8 = '﻿';
const FIN_DE_LINEA = '\r\n';

export function neutralizarFormula(texto: string): string {
  return INICIO_FORMULA.test(texto) ? `'${texto}` : texto;
}

export function escaparCelda(celda: CeldaCsv): string {
  if (celda === null || celda === undefined) return '';
  if (celda instanceof Decimal) return celda.toFixed(ESCALA_IMPORTE);
  if (typeof celda === 'number') return String(celda);
  const texto = neutralizarFormula(celda);
  return REQUIERE_COMILLAS.test(texto) ? `"${texto.replace(/"/g, '""')}"` : texto;
}

export function generarCsv(encabezados: readonly string[], filas: readonly (readonly CeldaCsv[])[]): string {
  const lineas = [encabezados, ...filas].map((fila) => fila.map(escaparCelda).join(','));
  return BOM_UTF8 + lineas.join(FIN_DE_LINEA) + FIN_DE_LINEA;
}
