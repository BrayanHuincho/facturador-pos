import { Decimal } from 'decimal.js';
import { numeroCompleto } from './catalogos.js';
import type { EmisorSunat } from './cliente.js';

type Valor = string | number | null | undefined;

const dec = (v: Valor): Decimal => new Decimal(v ?? 0);
const num = (v: Valor): number => dec(v).toNumber();
const redondear = (d: Decimal, decimales = 2): Decimal => d.toDecimalPlaces(decimales, Decimal.ROUND_HALF_UP);

export interface EmpresaSunat {
  ruc: string;
  razon_social: string;
  nombre_comercial: string | null;
  direccion: string | null;
  ubigeo: string | null;
  departamento: string | null;
  provincia: string | null;
  distrito: string | null;
  igv_porcentaje: string;
}

export interface ItemEnvio {
  codigo: string | null;
  descripcion: string;
  unidad: string;
  cantidad: string;
  precio_unitario: string;
  valor_unitario: string;
  descuento: string;
  afectacion: string;
  base: string;
  igv: string;
  icbper: string;
  total: string;
}

export interface ComprobanteEnvio {
  id: string;
  tipo: string;
  serie: string;
  correlativo: number;
  fecha_emision: string;
  hora_emision: string | null;
  moneda: string;
  tipo_cambio: string | null;
  forma_pago: string;
  cuotas: { monto: string | number; fecha_pago: string }[] | null;
  cliente_tipo_documento: string;
  cliente_numero_documento: string | null;
  cliente_nombre: string;
  cliente_direccion: string | null;
  op_gravadas: string;
  op_exoneradas: string;
  op_inafectas: string;
  op_gratuitas: string;
  descuento_total: string;
  igv: string;
  icbper: string;
  total: string;
  detraccion: Record<string, unknown> | null;
  leyendas: { codigo?: string; valor?: string; code?: string; value?: string }[] | null;
  afectado_tipo: string | null;
  afectado_serie: string | null;
  afectado_correlativo: number | null;
  motivo_codigo: string | null;
  motivo_descripcion: string | null;
  estado: string;
  hash: string | null;
  xml_path: string | null;
  cdr_path: string | null;
  pdf_path: string | null;
  entorno: 'beta' | 'produccion' | null;
  resumen_id: string | null;
  establecimiento_codigo: string | null;
  items: ItemEnvio[];
}

const esGratuito = (afectacion: string): boolean => /^(1[1-7]|21|3[1-7])$/.test(afectacion);
const esGravado = (afectacion: string): boolean => afectacion.startsWith('1');

export const esNota = (tipo: string): boolean => tipo === '07' || tipo === '08';

export const vaEnResumen = (c: Pick<ComprobanteEnvio, 'tipo' | 'afectado_tipo'>): boolean => c.tipo === '03' || (esNota(c.tipo) && c.afectado_tipo === '03');

export function emisorDe(e: Omit<EmpresaSunat, 'igv_porcentaje'>, codigoLocal?: string | null): EmisorSunat {
  return {
    ruc: e.ruc,
    razon_social: e.razon_social,
    nombre_comercial: e.nombre_comercial,
    direccion: e.direccion,
    ubigeo: e.ubigeo,
    departamento: e.departamento,
    provincia: e.provincia,
    distrito: e.distrito,
    cod_local: codigoLocal && /^\d{4}$/.test(codigoLocal) ? codigoLocal : '0000',
  };
}

export const nombreArchivo = (ruc: string, c: { tipo: string; serie: string; correlativo: number }): string => `${ruc}-${c.tipo}-${c.serie}-${c.correlativo}`;

export function cadenaQr(ruc: string, c: ComprobanteEnvio, hash: string | null): string {
  return [
    ruc,
    c.tipo,
    c.serie,
    String(c.correlativo).padStart(6, '0'),
    dec(c.igv).toFixed(2),
    dec(c.total).toFixed(2),
    c.fecha_emision,
    c.cliente_tipo_documento,
    c.cliente_numero_documento || '-',
    hash ?? '',
    '',
  ].join('|');
}

function itemGateway(i: ItemEnvio, nota: boolean, porcentajeIgv: string): Record<string, unknown> {
  const cantidad = dec(i.cantidad);
  const gratuito = esGratuito(i.afectacion);
  const impuestos = dec(i.igv).add(dec(i.icbper));
  const baseLista = redondear(cantidad.mul(dec(i.valor_unitario)));
  const monto = baseLista.sub(dec(i.base));
  const conDescuento = dec(i.descuento).gt(0) && !gratuito && monto.gt(0) && baseLista.gt(0) && cantidad.gt(0);
  const precioUnitario = conDescuento ? redondear(dec(i.base).add(dec(i.igv)).div(cantidad), 6) : dec(i.precio_unitario);
  const valorUnitario = conDescuento && nota ? redondear(dec(i.base).div(cantidad), 6) : dec(i.valor_unitario);
  return {
    codigo: i.codigo,
    descripcion: i.descripcion,
    unidad: i.unidad,
    cantidad: cantidad.toNumber(),
    valor_unitario: valorUnitario.toNumber(),
    ...(conDescuento && !nota ? { descuento: { base: baseLista.toNumber(), monto: monto.toNumber(), factor: redondear(monto.div(baseLista), 5).toNumber() } } : {}),
    precio_unitario: precioUnitario.toNumber(),
    tipo_afectacion_igv: i.afectacion,
    porcentaje_igv: esGravado(i.afectacion) ? num(porcentajeIgv) : 0,
    base_igv: num(i.base),
    igv: num(i.igv),
    isc: 0,
    icbper: num(i.icbper),
    factor_icbper: dec(i.icbper).gt(0) ? 0.5 : 0,
    total_impuestos: impuestos.toNumber(),
    valor_venta: num(i.base),
  };
}

export function documentoComprobante(c: ComprobanteEnvio, porcentajeIgv: string): { ruta: 'factura' | 'nota'; documento: Record<string, unknown> } {
  const nota = esNota(c.tipo);
  const credito = c.forma_pago === 'credito';
  const cuotas = credito && Array.isArray(c.cuotas) ? c.cuotas : [];
  const igvGratuitas = c.items.filter((i) => esGratuito(i.afectacion)).reduce((s, i) => s.add(dec(i.igv)), new Decimal(0));
  const valorVenta = dec(c.op_gravadas).add(dec(c.op_exoneradas)).add(dec(c.op_inafectas));
  const documento: Record<string, unknown> = {
    tipo_documento: c.tipo,
    serie: c.serie,
    correlativo: String(c.correlativo),
    fecha_emision: c.fecha_emision,
    hora_emision: c.hora_emision ? c.hora_emision.slice(0, 8) : null,
    fecha_vencimiento: null,
    tipo_operacion: c.detraccion ? '1001' : '0101',
    moneda: c.moneda,
    ...(c.moneda !== 'PEN' ? { tipo_cambio: num(c.tipo_cambio) } : {}),
    forma_pago: credito ? 'CREDITO' : 'CONTADO',
    cuotas: cuotas.map((q) => ({ monto: num(q.monto), fecha_pago: q.fecha_pago })),
    ...(credito && cuotas.length ? { monto_pendiente: cuotas.reduce((s, q) => s.add(dec(q.monto)), new Decimal(0)).toNumber() } : {}),
    cliente: {
      tipo_documento: c.cliente_tipo_documento,
      numero_documento: c.cliente_numero_documento || (c.cliente_tipo_documento === '0' ? '00000000' : ''),
      razon_social: c.cliente_nombre,
      direccion: c.cliente_direccion,
    },
    totales: {
      op_gravadas: num(c.op_gravadas),
      op_exoneradas: num(c.op_exoneradas),
      op_inafectas: num(c.op_inafectas),
      op_exportacion: 0,
      op_gratuitas: num(c.op_gratuitas),
      igv_gratuitas: igvGratuitas.toNumber(),
      igv: num(c.igv),
      isc: 0,
      icbper: num(c.icbper),
      total_impuestos: dec(c.igv).add(dec(c.icbper)).toNumber(),
      valor_venta: valorVenta.toNumber(),
      sub_total: num(c.total),
      descuentos: num(c.descuento_total),
      total: num(c.total),
    },
    items: c.items.map((i) => itemGateway(i, nota, porcentajeIgv)),
    leyendas: (c.leyendas ?? []).map((l) => ({ codigo: l.codigo ?? l.code, valor: l.valor ?? l.value })),
    detraccion: c.detraccion,
    observaciones: null,
    guias: null,
    documentos_relacionados: null,
  };
  if (nota) {
    documento.tipo_doc_afectado = c.afectado_tipo;
    documento.num_doc_afectado = c.afectado_serie && c.afectado_correlativo !== null ? numeroCompleto(c.afectado_serie, c.afectado_correlativo) : null;
    documento.cod_motivo = c.motivo_codigo;
    documento.des_motivo = c.motivo_descripcion;
  }
  return { ruta: nota ? 'nota' : 'factura', documento };
}
