import { Decimal } from 'decimal.js';
import { formatearImporte } from '../caja/calculos.js';

const ZONA_LIMA = 'America/Lima';
const FORMATO_FECHA = /^(\d{4})-(\d{2})-(\d{2})$/;

export function fechaEnLima(instante: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: ZONA_LIMA,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(instante);
}

export function esFechaValida(texto: string): boolean {
  const partes = FORMATO_FECHA.exec(texto);
  if (!partes) return false;
  const [anio, mes, dia] = [Number(partes[1]), Number(partes[2]), Number(partes[3])];
  const fecha = new Date(Date.UTC(anio, mes - 1, dia));
  return fecha.getUTCFullYear() === anio && fecha.getUTCMonth() === mes - 1 && fecha.getUTCDate() === dia;
}

export function resolverRango(
  consulta: { desde?: string | undefined; hasta?: string | undefined },
  ahora: Date,
): { desde: string; hasta: string } | null {
  const hasta = consulta.hasta ?? fechaEnLima(ahora);
  const desde = consulta.desde ?? hasta;
  return desde <= hasta ? { desde, hasta } : null;
}

export interface TotalPorTipo {
  tipo: string;
  documentos: number;
  total: string;
  igv: string;
}

export function construirKpis(filas: readonly TotalPorTipo[]) {
  let ventas = new Decimal(0);
  let notasCredito = new Decimal(0);
  let notasDebito = new Decimal(0);
  let igv = new Decimal(0);
  let documentosVenta = 0;
  for (const fila of filas) {
    if (fila.tipo === '07') {
      notasCredito = notasCredito.plus(fila.total);
      igv = igv.minus(fila.igv);
    } else if (fila.tipo === '08') {
      notasDebito = notasDebito.plus(fila.total);
      igv = igv.plus(fila.igv);
    } else {
      ventas = ventas.plus(fila.total);
      igv = igv.plus(fila.igv);
      documentosVenta += fila.documentos;
    }
  }
  const ticketPromedio = documentosVenta > 0 ? ventas.dividedBy(documentosVenta) : new Decimal(0);
  return {
    ventas_brutas: formatearImporte(ventas),
    notas_credito: formatearImporte(notasCredito),
    notas_debito: formatearImporte(notasDebito),
    ventas_netas: formatearImporte(ventas.minus(notasCredito).plus(notasDebito)),
    igv: formatearImporte(igv),
    documentos_venta: documentosVenta,
    ticket_promedio: formatearImporte(ticketPromedio),
  };
}
