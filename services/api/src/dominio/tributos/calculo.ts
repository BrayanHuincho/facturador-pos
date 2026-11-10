import { CERO, decimal, Decimal, ICBPER_POR_UNIDAD, IGV_POR_DEFECTO, redondear, type Valor } from './dinero.js';

export interface LineaComprobante {
  cantidad: Valor;
  precio: Valor;
  tipo_afectacion_igv?: string;
  descuento?: Valor | null;
  aplica_icbper?: boolean;
}

export interface ItemCalculado {
  cantidad: Decimal;
  valor_unitario: Decimal;
  precio_unitario: Decimal;
  tipo_afectacion_igv: string;
  porcentaje_igv: Decimal;
  base_igv: Decimal;
  igv: Decimal;
  icbper: Decimal;
  descuento: Decimal;
  total_impuestos: Decimal;
  valor_venta: Decimal;
  total: Decimal;
}

export interface TotalesComprobante {
  items: ItemCalculado[];
  op_gravadas: Decimal;
  op_exoneradas: Decimal;
  op_inafectas: Decimal;
  op_exportacion: Decimal;
  op_gratuitas: Decimal;
  igv_gratuitas: Decimal;
  igv: Decimal;
  icbper: Decimal;
  descuento_total: Decimal;
  total_impuestos: Decimal;
  valor_venta: Decimal;
  sub_total: Decimal;
  total: Decimal;
}

export const esGratuito = (tipo: string): boolean => /^(1[1-7]|21|3[1-7])$/.test(tipo);

export function calcularComprobante(
  lineas: LineaComprobante[],
  opciones: { precios_incluyen_igv: boolean; porcentaje_igv?: Valor },
): TotalesComprobante {
  const porcentaje = decimal(opciones.porcentaje_igv ?? IGV_POR_DEFECTO);
  const factor = porcentaje.div(100);
  const uno = decimal(1).add(factor);
  const acumulado = {
    op_gravadas: CERO,
    op_exoneradas: CERO,
    op_inafectas: CERO,
    op_exportacion: CERO,
    op_gratuitas: CERO,
    igv_gratuitas: CERO,
    igv: CERO,
    icbper: CERO,
    descuento_total: CERO,
  };

  const calculados = lineas.map((linea) => {
    const tipo = linea.tipo_afectacion_igv ?? '10';
    const cantidad = decimal(linea.cantidad);
    const precio = decimal(linea.precio);
    const gravado = tipo === '10' || (esGratuito(tipo) && tipo.startsWith('1'));
    const descuento = redondear(decimal(linea.descuento));
    const icbper = linea.aplica_icbper ? redondear(cantidad.mul(ICBPER_POR_UNIDAD)) : CERO;
    let base: Decimal;
    let igv: Decimal;
    if (gravado && opciones.precios_incluyen_igv) {
      const importe = redondear(cantidad.mul(precio)).sub(descuento);
      base = redondear(importe.div(uno));
      igv = importe.sub(base);
    } else {
      base = redondear(cantidad.mul(precio)).sub(descuento);
      igv = gravado ? redondear(base.mul(factor)) : CERO;
    }
    const valorUnitario = gravado && opciones.precios_incluyen_igv ? precio.div(uno) : precio;
    return { tipo, cantidad, gravado, descuento, base, igv, icbper, valorUnitario };
  });

  const gravadas = calculados.filter((c) => c.tipo === '10');
  if (!opciones.precios_incluyen_igv && gravadas.length > 1) {
    const baseGravada = gravadas.reduce((suma, c) => suma.add(c.base), CERO);
    const igvPorLineas = gravadas.reduce((suma, c) => suma.add(c.igv), CERO);
    const diferencia = redondear(baseGravada.mul(factor)).sub(igvPorLineas);
    if (!diferencia.isZero()) {
      const mayor = gravadas.reduce((a, c) => (c.base.gt(a.base) ? c : a));
      mayor.igv = mayor.igv.add(diferencia);
    }
  }

  const items = calculados.map<ItemCalculado>(({ tipo, cantidad, gravado, descuento, base, igv, icbper, valorUnitario }) => {
    const gratuito = esGratuito(tipo);
    const conDescuento = descuento.gt(0) && cantidad.gt(0) && !gratuito;
    const precioUnitario = conDescuento ? base.add(igv).div(cantidad) : gravado ? valorUnitario.mul(uno) : valorUnitario;

    if (gratuito) {
      acumulado.op_gratuitas = acumulado.op_gratuitas.add(base);
      acumulado.igv_gratuitas = acumulado.igv_gratuitas.add(igv);
    } else if (tipo === '10') {
      acumulado.op_gravadas = acumulado.op_gravadas.add(base);
      acumulado.igv = acumulado.igv.add(igv);
    } else if (tipo === '20') {
      acumulado.op_exoneradas = acumulado.op_exoneradas.add(base);
    } else if (tipo === '40') {
      acumulado.op_exportacion = acumulado.op_exportacion.add(base);
    } else {
      acumulado.op_inafectas = acumulado.op_inafectas.add(base);
    }
    acumulado.icbper = acumulado.icbper.add(icbper);
    acumulado.descuento_total = acumulado.descuento_total.add(descuento);

    return {
      cantidad,
      valor_unitario: redondear(valorUnitario, 6),
      precio_unitario: redondear(precioUnitario, 6),
      tipo_afectacion_igv: tipo,
      porcentaje_igv: gravado ? porcentaje : CERO,
      base_igv: base,
      igv,
      icbper,
      descuento,
      total_impuestos: igv.add(icbper),
      valor_venta: base,
      total: (gratuito ? CERO : base.add(igv)).add(icbper),
    };
  });

  const valorVenta = acumulado.op_gravadas.add(acumulado.op_exoneradas).add(acumulado.op_inafectas).add(acumulado.op_exportacion);
  const subTotal = valorVenta.add(acumulado.igv);
  return {
    items,
    ...acumulado,
    total_impuestos: acumulado.igv.add(acumulado.icbper),
    valor_venta: valorVenta,
    sub_total: subTotal,
    total: subTotal.add(acumulado.icbper),
  };
}

export interface ItemEmitido {
  cantidad: Valor;
  valor_unitario: Valor;
  precio_unitario: Valor;
  descuento: Valor;
  afectacion: string;
  base: Valor;
  igv: Valor;
  icbper: Valor;
  total: Valor;
}

export function totalesDeItemsEmitidos(emitidos: ItemEmitido[], porcentajeIgv: Valor = IGV_POR_DEFECTO): TotalesComprobante {
  const suma = (filtro: (item: ItemEmitido) => boolean, valor: (item: ItemEmitido) => Valor) =>
    emitidos.filter(filtro).reduce((acumulado, item) => acumulado.add(decimal(valor(item))), CERO);
  const todos = () => true;
  const deAfectacion = (tipo: string) => (item: ItemEmitido) => item.afectacion === tipo;
  const gratuitos = (item: ItemEmitido) => esGratuito(item.afectacion);
  const items = emitidos.map<ItemCalculado>((item) => {
    const igv = decimal(item.igv);
    const icbper = decimal(item.icbper);
    const base = decimal(item.base);
    return {
      cantidad: decimal(item.cantidad),
      valor_unitario: decimal(item.valor_unitario),
      precio_unitario: decimal(item.precio_unitario),
      tipo_afectacion_igv: item.afectacion,
      porcentaje_igv: igv.gt(0) ? decimal(porcentajeIgv) : CERO,
      base_igv: base,
      igv,
      icbper,
      descuento: decimal(item.descuento),
      total_impuestos: igv.add(icbper),
      valor_venta: base,
      total: decimal(item.total),
    };
  });
  const opGravadas = suma(deAfectacion('10'), (item) => item.base);
  const opExoneradas = suma(deAfectacion('20'), (item) => item.base);
  const opInafectas = suma(deAfectacion('30'), (item) => item.base);
  const opExportacion = suma(deAfectacion('40'), (item) => item.base);
  const igv = suma(deAfectacion('10'), (item) => item.igv);
  const icbper = suma(todos, (item) => item.icbper);
  const valorVenta = opGravadas.add(opExoneradas).add(opInafectas).add(opExportacion);
  const subTotal = valorVenta.add(igv);
  return {
    items,
    op_gravadas: opGravadas,
    op_exoneradas: opExoneradas,
    op_inafectas: opInafectas,
    op_exportacion: opExportacion,
    op_gratuitas: suma(gratuitos, (item) => item.base),
    igv_gratuitas: suma(gratuitos, (item) => item.igv),
    igv,
    icbper,
    descuento_total: suma(todos, (item) => item.descuento),
    total_impuestos: igv.add(icbper),
    valor_venta: valorVenta,
    sub_total: subTotal,
    total: subTotal.add(icbper),
  };
}

export interface DescuentoLineaSunat {
  base: Decimal;
  monto: Decimal;
  factor: Decimal;
}

export function descuentoLineaSunat(item: { cantidad: Valor; valor_unitario: Valor; valor_venta: Valor; descuento?: Valor | null }): DescuentoLineaSunat | null {
  if (!decimal(item.descuento).gt(0)) return null;
  const base = redondear(decimal(item.cantidad).mul(decimal(item.valor_unitario)));
  const monto = base.sub(decimal(item.valor_venta));
  if (!monto.gt(0) || !base.gt(0)) return null;
  return { base, monto, factor: redondear(monto.div(base), 5) };
}
