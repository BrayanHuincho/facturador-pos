import { describe, expect, it } from 'vitest';
import { calcularComprobante, descuentoLineaSunat, totalesDeItemsEmitidos, type ItemCalculado } from './calculo.js';
import { decimal, redondear } from './dinero.js';
import { montoEnLetras } from './letras.js';

describe('resultados del sistema de referencia', () => {
  it('boleta migrada 21 x 20 sin IGV', () => {
    const t = calcularComprobante([{ cantidad: 21, precio: 20 }], { precios_incluyen_igv: false });
    expect(t.items[0].igv.toFixed(2)).toBe('75.60');
    expect(t.items[0].precio_unitario.toFixed(2)).toBe('23.60');
    expect(t.op_gravadas.toFixed(2)).toBe('420.00');
    expect(t.igv.toFixed(2)).toBe('75.60');
    expect(t.total.toFixed(2)).toBe('495.60');
  });

  it('balón a 38 con IGV incluido', () => {
    const t = calcularComprobante([{ cantidad: 1, precio: 38 }], { precios_incluyen_igv: true });
    expect(t.op_gravadas.toFixed(2)).toBe('32.20');
    expect(t.igv.toFixed(2)).toBe('5.80');
    expect(t.total.toFixed(2)).toBe('38.00');
    expect(t.items[0].valor_unitario.toFixed(6)).toBe('32.203390');
  });

  it('valor unitario con cinco decimales vuelve a sumar 76.00', () => {
    const t = calcularComprobante([{ cantidad: 2, precio: (38 / 1.18).toFixed(5) }], { precios_incluyen_igv: false });
    expect(t.total.toFixed(2)).toBe('76.00');
  });

  it('118 con IGV incluido desglosa 100 + 18', () => {
    const t = calcularComprobante([{ cantidad: 1, precio: 118 }], { precios_incluyen_igv: true });
    expect(t.op_gravadas.toFixed(2)).toBe('100.00');
    expect(t.igv.toFixed(2)).toBe('18.00');
    expect(t.total.toFixed(2)).toBe('118.00');
  });

  it('10.00 incluido no se convierte en 9.99', () => {
    const t = calcularComprobante([{ cantidad: 1, precio: 10 }], { precios_incluyen_igv: true });
    expect(t.op_gravadas.toFixed(2)).toBe('8.47');
    expect(t.igv.toFixed(2)).toBe('1.53');
    expect(t.total.toFixed(2)).toBe('10.00');
  });

  it('separa exonerado e inafecto sin IGV', () => {
    const t = calcularComprobante(
      [
        { cantidad: 1, precio: 100, tipo_afectacion_igv: '20' },
        { cantidad: 2, precio: 10, tipo_afectacion_igv: '30' },
      ],
      { precios_incluyen_igv: false },
    );
    expect(t.op_exoneradas.toFixed(2)).toBe('100.00');
    expect(t.op_inafectas.toFixed(2)).toBe('20.00');
    expect(t.igv.toFixed(2)).toBe('0.00');
    expect(t.total.toFixed(2)).toBe('120.00');
    expect(t.items.map((i) => i.porcentaje_igv.toNumber())).toEqual([0, 0]);
  });

  it('exonerado con precio incluido no desglosa IGV', () => {
    const t = calcularComprobante([{ cantidad: 3, precio: '9.90', tipo_afectacion_igv: '20' }], { precios_incluyen_igv: true });
    expect(t.op_exoneradas.toFixed(2)).toBe('29.70');
    expect(t.total.toFixed(2)).toBe('29.70');
    expect(t.items[0].valor_unitario.toFixed(2)).toBe('9.90');
  });

  it('documento mixto de las tres afectaciones', () => {
    const t = calcularComprobante(
      [
        { cantidad: 2, precio: '59' },
        { cantidad: 1, precio: '10', tipo_afectacion_igv: '20' },
        { cantidad: 1, precio: '5', tipo_afectacion_igv: '30' },
      ],
      { precios_incluyen_igv: true },
    );
    expect(t.op_gravadas.toFixed(2)).toBe('100.00');
    expect(t.op_exoneradas.toFixed(2)).toBe('10.00');
    expect(t.op_inafectas.toFixed(2)).toBe('5.00');
    expect(t.igv.toFixed(2)).toBe('18.00');
    expect(t.valor_venta.toFixed(2)).toBe('115.00');
    expect(t.total.toFixed(2)).toBe('133.00');
  });

  it('gratuito va a op_gratuitas y no suma al total', () => {
    const t = calcularComprobante([{ cantidad: 1, precio: 100, tipo_afectacion_igv: '11' }], { precios_incluyen_igv: false });
    expect(t.op_gratuitas.toFixed(2)).toBe('100.00');
    expect(t.igv_gratuitas.toFixed(2)).toBe('18.00');
    expect(t.total.toFixed(2)).toBe('0.00');
    expect(t.items[0].total.toFixed(2)).toBe('0.00');
  });

  it('respeta un porcentaje de IGV distinto', () => {
    const t = calcularComprobante([{ cantidad: 1, precio: 110 }], { precios_incluyen_igv: true, porcentaje_igv: 10 });
    expect(t.op_gravadas.toFixed(2)).toBe('100.00');
    expect(t.igv.toFixed(2)).toBe('10.00');
  });
});

describe('redondeo y ajuste de céntimo', () => {
  it('HALF_UP en la mitad exacta', () => {
    expect(redondear(decimal('1.005')).toFixed(2)).toBe('1.01');
    expect(redondear(decimal('2.675')).toFixed(2)).toBe('2.68');
    expect(redondear(decimal('1.0049')).toFixed(2)).toBe('1.00');
  });

  it('el IGV del documento se calcula sobre el total y el céntimo va a la línea mayor', () => {
    const lineas = [
      { cantidad: 1, precio: '0.05' },
      { cantidad: 1, precio: '0.05' },
      { cantidad: 1, precio: '0.05' },
    ];
    const t = calcularComprobante(lineas, { precios_incluyen_igv: false });
    expect(t.igv.toFixed(2)).toBe('0.03');
    expect(t.total.toFixed(2)).toBe('0.18');
    expect(t.items.map((i) => i.igv.toFixed(2))).toEqual(['0.01', '0.01', '0.01']);
  });

  it('corrige hacia arriba en la primera línea de mayor base', () => {
    const t = calcularComprobante(
      [
        { cantidad: 1, precio: '0.02' },
        { cantidad: 1, precio: '0.02' },
        { cantidad: 1, precio: '0.02' },
      ],
      { precios_incluyen_igv: false },
    );
    expect(t.igv.toFixed(2)).toBe('0.01');
    expect(t.items.map((i) => i.igv.toFixed(2))).toEqual(['0.01', '0.00', '0.00']);
  });

  it('con una sola línea no hay ajuste', () => {
    const t = calcularComprobante([{ cantidad: 3, precio: '33.33' }], { precios_incluyen_igv: false });
    expect(t.op_gravadas.toFixed(2)).toBe('99.99');
    expect(t.igv.toFixed(2)).toBe('18.00');
  });

  it('con precios incluidos no ajusta y cada línea conserva lo cobrado', () => {
    const t = calcularComprobante(
      [
        { cantidad: 1, precio: '0.05' },
        { cantidad: 1, precio: '0.05' },
        { cantidad: 1, precio: '0.05' },
      ],
      { precios_incluyen_igv: true },
    );
    expect(t.total.toFixed(2)).toBe('0.15');
    expect(t.items.map((i) => i.valor_venta.add(i.igv).toFixed(2))).toEqual(['0.05', '0.05', '0.05']);
  });

  it('la suma de IGV por ítem siempre iguala el IGV del documento', () => {
    const t = calcularComprobante(
      [
        { cantidad: 3, precio: '33.33', descuento: '0.05' },
        { cantidad: 1, precio: '0.05' },
        { cantidad: 1, precio: '0.05' },
      ],
      { precios_incluyen_igv: false },
    );
    expect(t.items.reduce((suma, i) => suma.add(i.igv), decimal(0)).toFixed(2)).toBe(t.igv.toFixed(2));
  });

  it('no pierde precisión con importes que en double fallan', () => {
    const t = calcularComprobante([{ cantidad: '1.1', precio: '1.1' }], { precios_incluyen_igv: false });
    expect(t.op_gravadas.toFixed(2)).toBe('1.21');
    const s = calcularComprobante([{ cantidad: 3, precio: '89.9' }], { precios_incluyen_igv: false });
    expect(s.items[0].precio_unitario.toFixed(3)).toBe('106.082');
  });
});

describe('descuentos por línea', () => {
  function cumpleSunat(i: ItemCalculado) {
    const d = descuentoLineaSunat(i);
    const cantidad = i.cantidad;
    expect(i.precio_unitario.sub(i.valor_venta.add(i.igv).div(cantidad)).abs().lt('0.01')).toBe(true);
    const monto = d ? d.monto : decimal(0);
    expect(cantidad.mul(i.valor_unitario).sub(monto).sub(i.valor_venta).abs().lt('0.01')).toBe(true);
    if (d) expect(d.base.mul(d.factor).sub(monto).abs().lt('0.01')).toBe(true);
    return d;
  }

  it('reproduce la línea 2 de la F7E2-2955585', () => {
    const t = calcularComprobante(
      [
        { cantidad: 1, precio: 45 },
        { cantidad: 2, precio: 120, descuento: 20 },
      ],
      { precios_incluyen_igv: false },
    );
    const linea = t.items[1];
    expect(linea.valor_unitario.toFixed(2)).toBe('120.00');
    expect(linea.valor_venta.toFixed(2)).toBe('220.00');
    expect(linea.igv.toFixed(2)).toBe('39.60');
    expect(linea.precio_unitario.toFixed(2)).toBe('129.80');
    const d = cumpleSunat(linea)!;
    expect(d.base.toFixed(2)).toBe('240.00');
    expect(d.monto.toFixed(2)).toBe('20.00');
    expect(d.factor.toFixed(5)).toBe('0.08333');
    cumpleSunat(t.items[0]);
    expect(descuentoLineaSunat(t.items[0])).toBeNull();
    expect(t.total.toFixed(2)).toBe('312.70');
    expect(t.descuento_total.toFixed(2)).toBe('20.00');
  });

  it('con IGV incluido el descuento se cobra exacto y en el XML va sin IGV', () => {
    const t = calcularComprobante([{ cantidad: 3, precio: 59, descuento: '17.7' }], { precios_incluyen_igv: true });
    const i = t.items[0];
    expect(t.total.toFixed(2)).toBe('159.30');
    expect(i.valor_venta.toFixed(2)).toBe('135.00');
    expect(i.igv.toFixed(2)).toBe('24.30');
    expect(i.precio_unitario.toFixed(2)).toBe('53.10');
    const d = cumpleSunat(i)!;
    expect(d.base.toFixed(2)).toBe('150.00');
    expect(d.monto.toFixed(2)).toBe('15.00');
    expect(d.factor.toFixed(5)).toBe('0.10000');
  });

  it('céntimos que no dividen exacto siguen cuadrando', () => {
    const t = calcularComprobante(
      [
        { cantidad: 7, precio: '13.9', descuento: '3.33' },
        { cantidad: 1, precio: 10 },
      ],
      { precios_incluyen_igv: true },
    );
    for (const i of t.items) cumpleSunat(i);
    expect(t.total.toFixed(2)).toBe('103.97');
  });

  it('exonerada con descuento', () => {
    const t = calcularComprobante([{ cantidad: 4, precio: 25, tipo_afectacion_igv: '20', descuento: 10 }], { precios_incluyen_igv: false });
    const i = t.items[0];
    expect(i.valor_venta.toFixed(2)).toBe('90.00');
    expect(i.igv.toFixed(2)).toBe('0.00');
    expect(i.precio_unitario.toFixed(2)).toBe('22.50');
    expect(cumpleSunat(i)!.monto.toFixed(2)).toBe('10.00');
    expect(t.op_exoneradas.toFixed(2)).toBe('90.00');
  });

  it('sin descuento devuelve null', () => {
    expect(descuentoLineaSunat({ cantidad: 1, valor_unitario: 10, valor_venta: 10, descuento: 0 })).toBeNull();
  });
});

describe('nota que copia el comprobante emitido', () => {
  const emitido = (lineas: Parameters<typeof calcularComprobante>[0]) => {
    const original = calcularComprobante(lineas, { precios_incluyen_igv: true });
    return {
      original,
      copia: totalesDeItemsEmitidos(
        original.items.map((i) => ({ cantidad: i.cantidad, valor_unitario: i.valor_unitario, precio_unitario: i.precio_unitario, descuento: i.descuento, afectacion: i.tipo_afectacion_igv, base: i.base_igv, igv: i.igv, icbper: i.icbper, total: i.total })),
      ),
    };
  };

  it.each(['0.03', '10.00', '10.01', '1.19', '499.97'])('reproduce al céntimo un precio incluido de %s', (precio) => {
    const { original, copia } = emitido([{ cantidad: 1, precio }]);
    expect(copia.total.toFixed(2)).toBe(original.total.toFixed(2));
    expect(copia.igv.toFixed(2)).toBe(original.igv.toFixed(2));
    expect(copia.op_gravadas.toFixed(2)).toBe(original.op_gravadas.toFixed(2));
  });

  it('conserva ICBPER, descuentos y afectaciones', () => {
    const { original, copia } = emitido([
      { cantidad: 3, precio: '1.18', aplica_icbper: true },
      { cantidad: 7, precio: '13.9', descuento: '3.33' },
      { cantidad: 1, precio: 5, tipo_afectacion_igv: '20' },
      { cantidad: 1, precio: 2, tipo_afectacion_igv: '30' },
    ]);
    expect(copia.total.toFixed(2)).toBe(original.total.toFixed(2));
    expect(copia.icbper.toFixed(2)).toBe('1.50');
    expect(copia.descuento_total.toFixed(2)).toBe('3.33');
    expect(copia.op_exoneradas.toFixed(2)).toBe('5.00');
    expect(copia.op_inafectas.toFixed(2)).toBe('2.00');
  });
});

describe('ICBPER', () => {
  it('cobra S/ 0.50 por unidad sobre el total y fuera del IGV', () => {
    const t = calcularComprobante([{ cantidad: 3, precio: '1.18', aplica_icbper: true }], { precios_incluyen_igv: true });
    expect(t.items[0].icbper.toFixed(2)).toBe('1.50');
    expect(t.icbper.toFixed(2)).toBe('1.50');
    expect(t.op_gravadas.toFixed(2)).toBe('3.00');
    expect(t.igv.toFixed(2)).toBe('0.54');
    expect(t.sub_total.toFixed(2)).toBe('3.54');
    expect(t.total.toFixed(2)).toBe('5.04');
    expect(t.total_impuestos.toFixed(2)).toBe('2.04');
    expect(t.items[0].total.toFixed(2)).toBe('5.04');
    expect(t.items[0].precio_unitario.toFixed(2)).toBe('1.18');
  });

  it('no se aplica sin la marca', () => {
    const t = calcularComprobante([{ cantidad: 3, precio: 1 }], { precios_incluyen_igv: true });
    expect(t.icbper.toFixed(2)).toBe('0.00');
  });

  it('se suma también en líneas exoneradas y redondea cantidades fraccionadas', () => {
    const t = calcularComprobante([{ cantidad: '1.5', precio: 2, tipo_afectacion_igv: '20', aplica_icbper: true }], { precios_incluyen_igv: false });
    expect(t.icbper.toFixed(2)).toBe('0.75');
    expect(t.total.toFixed(2)).toBe('3.75');
  });
});

describe('importe en letras', () => {
  it.each([
    [495.6, 'SON: CUATROCIENTOS NOVENTA Y CINCO CON 60/100 SOLES'],
    [1001, 'SON: MIL UNO CON 00/100 SOLES'],
    [21000, 'SON: VEINTIUN MIL CON 00/100 SOLES'],
    [100, 'SON: CIEN CON 00/100 SOLES'],
    [100000, 'SON: CIEN MIL CON 00/100 SOLES'],
    [0, 'SON: CERO CON 00/100 SOLES'],
    ['0.05', 'SON: CERO CON 05/100 SOLES'],
    [31000, 'SON: TREINTA Y UN MIL CON 00/100 SOLES'],
    ['1234.5', 'SON: MIL DOSCIENTOS TREINTA Y CUATRO CON 50/100 SOLES'],
  ])('%s', (monto, esperado) => {
    expect(montoEnLetras(monto)).toBe(esperado);
  });

  it('dólares y millones', () => {
    expect(montoEnLetras(1_500_100.25, 'USD')).toBe('SON: UN MILLON QUINIENTOS MIL CIEN CON 25/100 DÓLARES AMERICANOS');
  });
});
