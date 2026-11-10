import { Decimal } from 'decimal.js';

export const ESCALA_IMPORTE = 2;
export const ESCALA_CANTIDAD = 4;
export const MEDIO_EFECTIVO = 'efectivo';

export function redondearImporte(valor: Decimal.Value): Decimal {
  return new Decimal(valor).toDecimalPlaces(ESCALA_IMPORTE, Decimal.ROUND_HALF_UP);
}

export function formatearImporte(valor: Decimal.Value): string {
  return redondearImporte(valor).toFixed(ESCALA_IMPORTE);
}

export function calcularEfectivoEsperado(entrada: {
  apertura: Decimal.Value;
  ventasEfectivo: Decimal.Value;
  ingresos: Decimal.Value;
  egresos: Decimal.Value;
}): Decimal {
  return redondearImporte(
    new Decimal(entrada.apertura)
      .plus(entrada.ventasEfectivo)
      .plus(entrada.ingresos)
      .minus(entrada.egresos),
  );
}

export function calcularDiferencia(contado: Decimal.Value, esperado: Decimal.Value): Decimal {
  return redondearImporte(new Decimal(contado).minus(esperado));
}

export interface DatosResumenTurno {
  apertura: Decimal.Value;
  pagosPorMedio: readonly { medio: string; total: string }[];
  ingresos: Decimal.Value;
  egresos: Decimal.Value;
}

export interface ResumenTurno {
  monto_apertura: string;
  ventas_efectivo: string;
  ingresos: string;
  egresos: string;
  monto_esperado: string;
  total_ventas: string;
  por_medio: { medio: string; total: string }[];
}

export function construirResumenTurno(datos: DatosResumenTurno): ResumenTurno {
  const ventasEfectivo = datos.pagosPorMedio
    .filter((fila) => fila.medio === MEDIO_EFECTIVO)
    .reduce((suma, fila) => suma.plus(fila.total), new Decimal(0));
  const porMedio = datos.pagosPorMedio.map((fila) => ({ medio: fila.medio, total: formatearImporte(fila.total) }));
  const totalVentas = porMedio.reduce((suma, fila) => suma.plus(fila.total), new Decimal(0));
  return {
    monto_apertura: formatearImporte(datos.apertura),
    ventas_efectivo: formatearImporte(ventasEfectivo),
    ingresos: formatearImporte(datos.ingresos),
    egresos: formatearImporte(datos.egresos),
    monto_esperado: calcularEfectivoEsperado({
      apertura: datos.apertura,
      ventasEfectivo,
      ingresos: datos.ingresos,
      egresos: datos.egresos,
    }).toFixed(ESCALA_IMPORTE),
    total_ventas: formatearImporte(totalVentas),
    por_medio: porMedio,
  };
}

export function usuarioFiltrado(usuario: { id: string; rol: string }): string | null {
  return usuario.rol === 'admin' || usuario.rol === 'contador' ? null : usuario.id;
}
