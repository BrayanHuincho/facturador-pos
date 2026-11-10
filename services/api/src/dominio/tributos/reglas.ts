import { CERO, decimal, Decimal, redondear, type Valor } from './dinero.js';
import { montoEnLetras } from './letras.js';

export class ErrorRegla extends Error {
  constructor(
    readonly codigo: string,
    mensaje: string,
    readonly status = 422,
  ) {
    super(mensaje);
    this.name = 'ErrorRegla';
  }
}

const falla = (codigo: string, mensaje: string): never => {
  throw new ErrorRegla(codigo, mensaje);
};

export type TipoComprobante = '01' | '03' | '07' | '08' | 'NV';
export type TipoDocumentoIdentidad = '0' | '1' | '4' | '6' | '7';
export type Moneda = 'PEN' | 'USD';

export const TOPE_BOLETA_SIN_DOCUMENTO = 700;
export const DIAS_PARA_BAJA = 7;
export const ES_RUC = /^(10|15|16|17|20)\d{9}$/;

export const MOTIVOS_NOTA_CREDITO = [
  { codigo: '01', etiqueta: 'Anulación de la operación' },
  { codigo: '02', etiqueta: 'Anulación por error en el RUC' },
  { codigo: '03', etiqueta: 'Corrección por error en la descripción' },
  { codigo: '04', etiqueta: 'Descuento global' },
  { codigo: '05', etiqueta: 'Descuento por ítem' },
  { codigo: '06', etiqueta: 'Devolución total' },
  { codigo: '07', etiqueta: 'Devolución por ítem' },
  { codigo: '08', etiqueta: 'Bonificación' },
  { codigo: '09', etiqueta: 'Disminución en el valor' },
  { codigo: '10', etiqueta: 'Otros conceptos' },
  { codigo: '11', etiqueta: 'Ajuste de operaciones de exportación con sustento' },
  { codigo: '12', etiqueta: 'Ajuste de operaciones de exportación sin sustento' },
] as const;

export const MOTIVOS_NOTA_DEBITO = [
  { codigo: '01', etiqueta: 'Intereses por mora' },
  { codigo: '02', etiqueta: 'Aumento en el valor' },
  { codigo: '03', etiqueta: 'Penalidades u otros conceptos' },
] as const;

export const MOTIVOS_QUE_ANULAN: ReadonlySet<string> = new Set(['01', '02', '06']);

export function motivoDeNota(tipo: '07' | '08', codigo: string): { codigo: string; etiqueta: string } {
  const motivos: readonly { codigo: string; etiqueta: string }[] = tipo === '07' ? MOTIVOS_NOTA_CREDITO : MOTIVOS_NOTA_DEBITO;
  const motivo = motivos.find((m) => m.codigo === codigo);
  if (!motivo) return falla('MOTIVO_INVALIDO', 'Motivo no válido para este tipo de nota.');
  return motivo;
}

export const notaCopiaElAfectado = (tipo: '07' | '08', motivoCodigo: string, conItems: boolean): boolean =>
  !conItems || (tipo === '07' && MOTIVOS_QUE_ANULAN.has(motivoCodigo));

export function validarSaldoNota(totalNota: Decimal, totalAfectado: Valor, acreditado: Valor): void {
  const disponible = decimal(totalAfectado).sub(decimal(acreditado));
  if (totalNota.greaterThan(disponible)) {
    falla('NOTA_EXCEDE_SALDO', `La nota de crédito (${totalNota.toFixed(2)}) supera lo que queda por acreditar del comprobante (${disponible.toFixed(2)}).`);
  }
}

export const letraDeSerie = (tipoAfectado: string): 'F' | 'B' => (tipoAfectado === '01' ? 'F' : 'B');

export const numeroCompleto = (serie: string, correlativo: number | string): string => `${serie}-${String(correlativo).padStart(6, '0')}`;

export interface DocumentoCliente {
  tipo_documento: TipoDocumentoIdentidad;
  numero_documento: string | null;
}

export const esSinDocumento = (cliente: DocumentoCliente): boolean => {
  const numero = (cliente.numero_documento ?? '').trim();
  return cliente.tipo_documento === '0' || /^0+$/.test(numero) || numero === '';
};

export function validarCliente(tipo: TipoComprobante, cliente: DocumentoCliente, total: Decimal, moneda: Moneda): void {
  const numero = (cliente.numero_documento ?? '').trim();
  if (tipo === '01' && (cliente.tipo_documento !== '6' || !ES_RUC.test(numero))) {
    falla('FACTURA_REQUIERE_RUC', 'La factura exige un cliente con RUC válido de 11 dígitos. Para personas sin RUC emite una boleta.');
  }
  if (cliente.tipo_documento === '6' && !ES_RUC.test(numero)) falla('DOCUMENTO_INVALIDO', 'El RUC debe tener 11 dígitos y empezar por 10, 15, 16, 17 o 20.');
  if (cliente.tipo_documento === '1' && !/^\d{8}$/.test(numero)) falla('DOCUMENTO_INVALIDO', 'El DNI debe tener 8 dígitos.');
  if ((cliente.tipo_documento === '4' || cliente.tipo_documento === '7') && !/^[A-Za-z0-9]{4,15}$/.test(numero)) {
    falla('DOCUMENTO_INVALIDO', 'El número de documento no es válido.');
  }
  if (tipo === '03' && esSinDocumento(cliente) && moneda === 'PEN' && total.greaterThan(TOPE_BOLETA_SIN_DOCUMENTO)) {
    falla('BOLETA_REQUIERE_DOCUMENTO', `Una boleta de más de S/ ${TOPE_BOLETA_SIN_DOCUMENTO} debe identificar al cliente con su DNI, RUC o carné.`);
  }
}

export function validarTipoCambio(moneda: Moneda, tipoCambio: Valor | null | undefined): void {
  if (moneda !== 'PEN' && !decimal(tipoCambio).gt(0)) {
    falla('TIPO_CAMBIO_REQUERIDO', 'El tipo de cambio es obligatorio cuando la moneda es USD. Consulta el tipo de cambio del día en SUNAT o en el BCRP.');
  }
}

export const diasEntre = (desde: string, hasta: string): number =>
  Math.round((Date.parse(`${hasta}T00:00:00Z`) - Date.parse(`${desde}T00:00:00Z`)) / 86_400_000);

export function validarFechaEmision(fecha: string, hoy: string, tipoBase: '01' | '03'): void {
  if (fecha > hoy) falla('FECHA_FUTURA', 'La fecha de emisión no puede ser posterior a hoy.');
  const maximo = tipoBase === '01' ? 3 : 7;
  if (diasEntre(fecha, hoy) > maximo) {
    falla('FECHA_FUERA_DE_PLAZO', `SUNAT solo admite ${tipoBase === '01' ? 'facturas' : 'boletas'} con hasta ${maximo} días de antigüedad.`);
  }
}

export function validarFechaNota(fecha: string, fechaAfectado: string): void {
  if (fecha < fechaAfectado) falla('FECHA_ANTERIOR_AL_AFECTADO', 'La nota no puede ser anterior al comprobante que modifica.');
}

export interface Cuota {
  monto: string;
  fecha_pago: string;
}

export function validarCuotas(cuotas: { monto: Valor; fecha_pago: string }[] | undefined, neto: Decimal, fechaEmision: string): Cuota[] {
  if (!cuotas?.length) return falla('CUOTAS_REQUERIDAS', 'Una venta al crédito necesita al menos una cuota con su fecha de pago.');
  const suma = cuotas.reduce((acumulado, cuota) => acumulado.add(decimal(cuota.monto)), CERO);
  if (!redondear(suma).equals(redondear(neto))) {
    falla('CUOTAS_NO_CUADRAN', `Las cuotas suman ${redondear(suma).toFixed(2)} y deben sumar ${redondear(neto).toFixed(2)}.`);
  }
  if (cuotas.some((cuota) => cuota.fecha_pago <= fechaEmision)) falla('CUOTA_FECHA_INVALIDA', 'Cada cuota debe vencer después de la fecha de emisión.');
  return [...cuotas]
    .sort((a, b) => a.fecha_pago.localeCompare(b.fecha_pago))
    .map((cuota) => ({ monto: redondear(decimal(cuota.monto)).toFixed(2), fecha_pago: cuota.fecha_pago }));
}

export function validarVencimiento(vencimiento: string | null | undefined, fechaEmision: string, ultimaCuota?: string | null): void {
  if (!vencimiento) return;
  if (vencimiento < fechaEmision) falla('VENCIMIENTO_ANTES_DE_EMISION', 'La fecha de vencimiento no puede ser anterior a la de emisión.');
  if (ultimaCuota && vencimiento < ultimaCuota) falla('VENCIMIENTO_ANTES_DE_CUOTA', 'La fecha de vencimiento no puede ser anterior a la última cuota.');
}

export function pendienteDeCredito(neto: Decimal, pagadoPrevio: Valor = 0): Decimal {
  const pendiente = redondear(neto.sub(decimal(pagadoPrevio)));
  if (!pendiente.greaterThan(0)) return falla('YA_PAGADO', 'Ya está pagado: emítelo al contado.');
  return pendiente;
}

export function validarDescuentos(lineas: { cantidad: Valor; precio: Valor; descuento?: Valor | null }[]): void {
  lineas.forEach((linea, indice) => {
    if (redondear(decimal(linea.descuento)).greaterThan(redondear(decimal(linea.cantidad).mul(decimal(linea.precio))))) {
      falla('DESCUENTO_EXCEDE_IMPORTE', `El descuento del ítem ${indice + 1} supera su importe.`);
    }
  });
}

export interface Leyenda {
  code: string;
  value: string;
}

export function leyendasDe(total: Decimal, moneda: Moneda, opciones: { gratuito?: boolean; detraccion?: boolean } = {}): Leyenda[] {
  const leyendas: Leyenda[] = [{ code: '1000', value: montoEnLetras(total, moneda) }];
  if (opciones.gratuito) leyendas.push({ code: '1002', value: 'TRANSFERENCIA GRATUITA DE UN BIEN Y/O SERVICIO PRESTADO GRATUITAMENTE' });
  if (opciones.detraccion) leyendas.push({ code: '2006', value: 'Operación sujeta a detracción' });
  return leyendas;
}

export const montoDetraccion = (total: Decimal, porcentaje: Valor): Decimal => redondear(total.mul(decimal(porcentaje)).div(100), 0);

export function validarDetraccion(tipo: TipoComprobante, moneda: Moneda, total: Decimal, porcentaje: Valor): Decimal {
  if (tipo !== '01') falla('DETRACCION_SOLO_FACTURA', 'La detracción solo aplica a facturas.');
  if (moneda !== 'PEN') falla('DETRACCION_SOLO_SOLES', 'Emite en soles las facturas con detracción.');
  if (!total.greaterThan(TOPE_BOLETA_SIN_DOCUMENTO)) falla('DETRACCION_MINIMO', 'La detracción aplica a operaciones de más de S/ 700.');
  return montoDetraccion(total, porcentaje);
}

export interface PagoEntrada {
  medio: string;
  monto: Valor;
  referencia?: string | null;
}

export interface PagoNeto {
  medio: string;
  monto: Decimal;
  referencia: string | null;
}

export interface LiquidacionPagos {
  pagos: PagoNeto[];
  recibido: Decimal;
  vuelto: Decimal;
  pagado: Decimal;
}

export function liquidarPagos(pagos: PagoEntrada[], importe: Decimal, formaPago: 'contado' | 'credito'): LiquidacionPagos {
  const lista = pagos
    .map((pago) => ({ medio: pago.medio, monto: redondear(decimal(pago.monto)), referencia: pago.referencia ?? null }))
    .filter((pago) => pago.monto.gt(0));
  const recibido = lista.reduce((suma, pago) => suma.add(pago.monto), CERO);
  if (formaPago === 'credito') {
    pendienteDeCredito(importe, recibido);
    return { pagos: lista, recibido, vuelto: CERO, pagado: recibido };
  }
  if (recibido.lessThan(importe)) falla('PAGO_INSUFICIENTE', `Los pagos suman ${recibido.toFixed(2)} y el importe a cobrar es ${importe.toFixed(2)}.`);
  const vuelto = recibido.sub(importe);
  const efectivo = lista.filter((pago) => pago.medio === 'efectivo').reduce((suma, pago) => suma.add(pago.monto), CERO);
  if (vuelto.greaterThan(efectivo)) falla('PAGO_EXCEDE_TOTAL', 'Los pagos con Yape, Plin, tarjeta o transferencia no pueden pasar del total: el vuelto solo sale del efectivo.');
  let porDescontar = vuelto;
  const netos = lista
    .map((pago) => {
      if (pago.medio !== 'efectivo' || porDescontar.isZero()) return pago;
      const descontado = Decimal.min(pago.monto, porDescontar);
      porDescontar = porDescontar.sub(descontado);
      return { ...pago, monto: pago.monto.sub(descontado) };
    })
    .filter((pago) => pago.monto.gt(0));
  return { pagos: netos, recibido, vuelto, pagado: importe };
}

export interface DatosQr {
  ruc: string;
  tipo: string;
  serie: string;
  correlativo: number;
  igv: Valor;
  total: Valor;
  fecha_emision: string;
  cliente_tipo_documento: string;
  cliente_numero_documento: string | null;
  hash: string | null;
}

export function cadenaQr(datos: DatosQr): string {
  return [
    datos.ruc,
    datos.tipo,
    datos.serie,
    String(datos.correlativo).padStart(6, '0'),
    decimal(datos.igv).toFixed(2),
    decimal(datos.total).toFixed(2),
    datos.fecha_emision.slice(0, 10),
    datos.cliente_tipo_documento,
    datos.cliente_numero_documento || '0',
    datos.hash ?? '',
  ].join('|');
}

export type EstadoSunat = 'aceptado' | 'observado' | 'rechazado' | 'error';

export function estadoPorCodigo(codigo: string | null | undefined, exito: boolean): EstadoSunat {
  const numero = codigo !== null && codigo !== undefined && /^\d+$/.test(codigo) ? Number(codigo) : Number.NaN;
  if (exito && (numero === 0 || codigo === null || codigo === undefined || codigo === '')) return 'aceptado';
  if (Number.isNaN(numero)) return 'error';
  if (numero >= 4000) return 'observado';
  if (numero >= 2000) return 'rechazado';
  if (numero === 0) return 'aceptado';
  return 'error';
}

export const numeroOcupado = (comprobante: { estado: string; sunat_codigo?: string | null }): boolean =>
  comprobante.estado === 'error' && /^1033(?!\d)/.test((comprobante.sunat_codigo ?? '').trim());

export type ClaseAnulacion = 'local' | 'resumen' | 'baja';

export interface ComprobanteAnulable {
  tipo: string;
  estado: string;
  fecha_emision: string;
  afectado_tipo?: string | null;
  sunat_codigo?: string | null;
}

export function claseDeAnulacion(comprobante: ComprobanteAnulable, hoy: string): ClaseAnulacion {
  if (comprobante.estado === 'anulado') throw new ErrorRegla('YA_ANULADO', 'El comprobante ya está anulado.', 409);
  if (comprobante.estado === 'por_anular') throw new ErrorRegla('ANULACION_EN_TRAMITE', 'Ya hay una anulación en trámite.', 409);
  if (comprobante.tipo === 'NV' || comprobante.estado === 'rechazado' || numeroOcupado(comprobante)) return 'local';
  if (comprobante.estado !== 'aceptado' && comprobante.estado !== 'observado') {
    falla('NO_SE_PUEDE_ANULAR', 'Solo se anula un comprobante aceptado por SUNAT. Si quedó pendiente o con error, reenvíalo primero.');
  }
  if (diasEntre(comprobante.fecha_emision, hoy) > DIAS_PARA_BAJA) {
    falla('PLAZO_DE_BAJA_VENCIDO', `Pasaron más de ${DIAS_PARA_BAJA} días desde su emisión: SUNAT ya no admite la baja. Emite una nota de crédito por anulación.`);
  }
  return comprobante.tipo === '03' || comprobante.afectado_tipo === '03' ? 'resumen' : 'baja';
}

export interface ComprobanteParaResumen {
  tipo: string;
  serie: string;
  correlativo: number;
  cliente_tipo_documento: string;
  cliente_numero_documento: string | null;
  total: Valor;
  op_gravadas: Valor;
  op_exoneradas: Valor;
  op_inafectas: Valor;
  op_gratuitas: Valor;
  igv: Valor;
  icbper: Valor;
  afectado_tipo?: string | null;
  afectado_serie?: string | null;
  afectado_correlativo?: number | null;
}

export function detalleResumen(comprobante: ComprobanteParaResumen, estado: '1' | '3') {
  const importe = (valor: Valor) => decimal(valor).toNumber();
  return {
    tipo_documento: comprobante.tipo,
    serie_numero: numeroCompleto(comprobante.serie, comprobante.correlativo),
    estado,
    cliente_tipo: comprobante.cliente_tipo_documento,
    cliente_numero: comprobante.cliente_numero_documento || '00000000',
    total: importe(comprobante.total),
    mto_oper_gravadas: importe(comprobante.op_gravadas),
    mto_oper_exoneradas: importe(comprobante.op_exoneradas),
    mto_oper_inafectas: importe(comprobante.op_inafectas),
    mto_oper_gratuitas: importe(comprobante.op_gratuitas),
    mto_igv: importe(comprobante.igv),
    mto_isc: 0,
    mto_icbper: importe(comprobante.icbper),
    documento_referencia:
      comprobante.afectado_tipo && comprobante.afectado_serie && comprobante.afectado_correlativo
        ? { tipo_documento: comprobante.afectado_tipo, numero_documento: numeroCompleto(comprobante.afectado_serie, comprobante.afectado_correlativo) }
        : null,
  };
}

export function detalleBaja(comprobante: { tipo: string; serie: string; correlativo: number }, motivo: string) {
  return {
    tipo_documento: comprobante.tipo,
    serie: comprobante.serie,
    correlativo: String(comprobante.correlativo).padStart(6, '0'),
    motivo_especifico: motivo.slice(0, 100),
  };
}
