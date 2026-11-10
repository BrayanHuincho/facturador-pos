import { describe, expect, it } from 'vitest';
import { construirKpis, esFechaValida, fechaEnLima, resolverRango } from './calculos.js';

describe('fechaEnLima', () => {
  it('aplica UTC-5 en el cambio de día', () => {
    expect(fechaEnLima(new Date('2026-03-01T04:59:59Z'))).toBe('2026-02-28');
    expect(fechaEnLima(new Date('2026-03-01T05:00:00Z'))).toBe('2026-03-01');
  });
});

describe('esFechaValida', () => {
  it('acepta fechas reales', () => {
    expect(esFechaValida('2024-02-29')).toBe(true);
  });

  it.each(['2026-02-30', '2026-13-01', '01/02/2026', '2026-1-1', ''])('rechaza %j', (texto) => {
    expect(esFechaValida(texto)).toBe(false);
  });
});

describe('resolverRango', () => {
  const ahora = new Date('2026-03-01T04:00:00Z');

  it('usa el día de Lima por defecto', () => {
    expect(resolverRango({}, ahora)).toEqual({ desde: '2026-02-28', hasta: '2026-02-28' });
  });

  it('completa hasta con hoy y desde con hasta', () => {
    expect(resolverRango({ desde: '2026-02-01' }, ahora)).toEqual({ desde: '2026-02-01', hasta: '2026-02-28' });
    expect(resolverRango({ hasta: '2026-01-15' }, ahora)).toEqual({ desde: '2026-01-15', hasta: '2026-01-15' });
  });

  it('devuelve null con rango invertido', () => {
    expect(resolverRango({ desde: '2026-02-02', hasta: '2026-02-01' }, ahora)).toBeNull();
  });
});

describe('construirKpis', () => {
  it('resta notas de crédito y suma notas de débito', () => {
    const kpis = construirKpis([
      { tipo: '01', documentos: 2, total: '200.00', igv: '30.51' },
      { tipo: '03', documentos: 1, total: '100.00', igv: '15.25' },
      { tipo: 'NV', documentos: 1, total: '50.00', igv: '0.00' },
      { tipo: '07', documentos: 1, total: '40.00', igv: '6.10' },
      { tipo: '08', documentos: 1, total: '10.00', igv: '1.53' },
    ]);
    expect(kpis).toEqual({
      ventas_brutas: '350.00',
      notas_credito: '40.00',
      notas_debito: '10.00',
      ventas_netas: '320.00',
      igv: '41.19',
      documentos_venta: 4,
      ticket_promedio: '87.50',
    });
  });

  it('no divide entre cero sin ventas', () => {
    expect(construirKpis([]).ticket_promedio).toBe('0.00');
  });
});
