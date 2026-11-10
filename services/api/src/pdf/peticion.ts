import { Decimal } from 'decimal.js';
import { MOTIVOS_TRASLADO, NOMBRE_DOCUMENTO, numeroCompleto } from '../sunat/catalogos.js';

export type FormatoPdf = 'a4' | 'ticket80' | 'ticket58';
export type FormatoGateway = 'A4' | '80mm' | '50mm';

export interface PeticionPdf {
  plantilla: string;
  formato: FormatoGateway;
  logo: string | null;
  qr_texto: string | null;
  datos: Record<string, unknown>;
}

const FORMATOS: Record<FormatoPdf, FormatoGateway> = { a4: 'A4', ticket80: '80mm', ticket58: '50mm' };
const TITULOS: Record<string, string> = {
  '01': 'FACTURA ELECTRÓNICA',
  '03': 'BOLETA DE VENTA ELECTRÓNICA',
  '07': 'NOTA DE CRÉDITO ELECTRÓNICA',
  '08': 'NOTA DE DÉBITO ELECTRÓNICA',
  NV: 'NOTA DE VENTA',
};
const REPRESENTACIONES: Record<string, string> = {
  '01': 'Representación impresa de la Factura Electrónica',
  '03': 'Representación impresa de la Boleta de Venta Electrónica',
  '07': 'Representación impresa de la Nota de Crédito Electrónica',
  '08': 'Representación impresa de la Nota de Débito Electrónica',
  NV: '',
};
const AFECTADOS: Record<string, string> = { '01': 'Factura electrónica', '03': 'Boleta de venta electrónica' };
const CONSULTA_SUNAT = 'https://e-consulta.sunat.gob.pe/ol-ti-itconsvalicpe/ConsValiCpe.htm';

type Valor = string | number | null | undefined;

export interface EmpresaPdf {
  ruc: string;
  razon_social: string;
  nombre_comercial: string | null;
  direccion: string | null;
  distrito: string | null;
  provincia: string | null;
  departamento: string | null;
  telefono: string | null;
  correo: string | null;
  plantilla_pdf: string | null;
}

export interface ItemPdf {
  codigo: string | null;
  descripcion: string;
  unidad: string;
  cantidad: string;
  precio_unitario: string;
  valor_unitario: string;
  descuento: string;
  afectacion: string;
  total: string;
}

export interface ComprobantePdf {
  tipo: string;
  serie: string;
  correlativo: number;
  fecha_emision: string;
  hora_emision: string | null;
  moneda: string;
  tipo_cambio: string | null;
  forma_pago: string;
  cuotas: { monto: Valor; fecha_pago: string }[] | null;
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
  detraccion: { codigo_bien_servicio?: string; porcentaje?: Valor; monto?: Valor; cuenta_banco?: string } | null;
  leyendas: { codigo?: string; valor?: string; code?: string; value?: string }[] | null;
  afectado_tipo: string | null;
  afectado_serie: string | null;
  afectado_correlativo: number | null;
  motivo_codigo: string | null;
  motivo_descripcion: string | null;
  estado: string;
  hash: string | null;
  qr: string | null;
  entorno: string | null;
  establecimiento_direccion: string | null;
  establecimiento_telefono?: string | null;
  usuario_nombre: string | null;
  igv_porcentaje: string;
  items: ItemPdf[];
}

export interface ItemGuiaPdf {
  codigo: string | null;
  descripcion: string;
  unidad: string;
  cantidad: string;
}

export interface GuiaPdf {
  serie: string;
  correlativo: number;
  fecha_emision: string;
  fecha_traslado: string | null;
  motivo_codigo: string | null;
  modalidad: string | null;
  peso_total: string | null;
  unidad_peso: string | null;
  bultos: number | null;
  partida_ubigeo: string | null;
  partida_direccion: string | null;
  llegada_ubigeo: string | null;
  llegada_direccion: string | null;
  destinatario_tipo_documento: string | null;
  destinatario_numero_documento: string | null;
  destinatario_nombre: string | null;
  transportista: { ruc?: string; razon_social?: string; mtc?: string } | null;
  conductor: { tipo_documento?: string; numero?: string; nombres?: string; apellidos?: string; licencia?: string; vehiculo_m1l?: boolean } | null;
  vehiculo_placa: string | null;
  relacionado: string | null;
  estado: string;
  hash: string | null;
  qr: string | null;
  entorno: string | null;
  establecimiento_direccion: string | null;
  items: ItemGuiaPdf[];
}

const dec = (v: Valor): Decimal => new Decimal(v ?? 0);
const hayImporte = (v: Valor): boolean => !dec(v).isZero();
const fecha = (iso: string): string => iso.slice(0, 10).split('-').reverse().join('/');
const dato = (v: string | null | undefined): string | null => (v && v.trim() && v.trim() !== '-' ? v.trim() : null);

export function miles(v: Valor): string {
  const [entero, decimales] = dec(v).toFixed(2, Decimal.ROUND_HALF_UP).split('.');
  return `${entero.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}.${decimales}`;
}

const sinCeros = (v: Valor): string => dec(v).toDecimalPlaces(4).toString();

function precio(v: Valor): string {
  const d = dec(v);
  const seis = d.toFixed(6);
  return d.toDecimalPlaces(2).equals(d) ? d.toFixed(2) : seis.replace(/0+$/, '');
}

export const formatoValido = (formato: string): FormatoPdf => {
  const limpio = formato.replace(/^pdf-/, '');
  if (limpio === 'a4' || limpio === 'ticket80' || limpio === 'ticket58') return limpio;
  throw new Error(`Formato de PDF desconocido: ${formato}`);
};

const plantillaDe = (e: EmpresaPdf): string => e.plantilla_pdf || 'clasica';

const esGratuito = (afectacion: string): boolean => /^(1[1-7]|21|3[1-7])$/.test(afectacion);

function etiquetaAfectacion(afectacion: string): string | null {
  if (esGratuito(afectacion)) return 'Gratuito';
  if (afectacion.startsWith('2')) return 'Exonerado';
  if (afectacion.startsWith('3')) return 'Inafecto';
  return null;
}

function selloDe(estado: string): string | null {
  if (estado === 'anulado' || estado === 'por_anular') return 'ANULADO';
  if (estado === 'rechazado') return 'RECHAZADO';
  return null;
}

function emisorPdf(e: EmpresaPdf, direccionLocal: string | null, telefonoLocal?: string | null) {
  const ubicacion = [e.distrito, e.provincia, e.departamento].map(dato).filter(Boolean).join(' - ');
  const fiscal = [dato(e.direccion), ubicacion].filter(Boolean).join(', ');
  const local = dato(direccionLocal);
  const comercial = dato(e.nombre_comercial);
  return {
    razon_social: e.razon_social,
    nombre_comercial: comercial && comercial.toUpperCase() !== e.razon_social.trim().toUpperCase() ? comercial : null,
    ruc: e.ruc,
    direccion: fiscal || null,
    sucursal: local && !fiscal.toUpperCase().startsWith(local.toUpperCase()) ? local : null,
    telefono: dato(telefonoLocal) ?? dato(e.telefono),
    email: dato(e.correo),
    web: null,
  };
}

export function peticionComprobante(c: ComprobantePdf, empresa: EmpresaPdf, formato: FormatoPdf, logo: string | null): PeticionPdf {
  if (!TITULOS[c.tipo]) throw new Error(`Tipo de comprobante sin plantilla: ${c.tipo}`);
  const esVenta = c.tipo === '01' || c.tipo === '03' || c.tipo === 'NV';
  const esNota = c.tipo === '07' || c.tipo === '08';
  const electronico = c.tipo !== 'NV';
  const simbolo = c.moneda === 'USD' ? 'US$' : 'S/';
  const leyendas = (c.leyendas ?? []).map((l) => ({ codigo: l.codigo ?? l.code, valor: l.valor ?? l.value }));
  const letras = leyendas.find((l) => l.codigo === '1000')?.valor ?? null;
  const cuotas = c.forma_pago === 'credito' && Array.isArray(c.cuotas) ? c.cuotas : [];
  const conDetraccion = Boolean(c.detraccion?.porcentaje);
  const completo = c.tipo === '01' || c.tipo === '03';
  const totales: { etiqueta: string; valor: string }[] = [];
  const fila = (etiqueta: string, v: Valor, siempre = false) => {
    if (siempre || hayImporte(v)) totales.push({ etiqueta, valor: miles(v) });
  };
  fila('Op. gravadas', c.op_gravadas, completo);
  fila('Op. exoneradas', c.op_exoneradas, completo);
  fila('Op. inafectas', c.op_inafectas, completo);
  fila('Op. gratuitas', c.op_gratuitas);
  if (hayImporte(c.descuento_total) || completo) totales.push({ etiqueta: 'Descuentos', valor: hayImporte(c.descuento_total) ? `-${miles(c.descuento_total)}` : '0.00' });
  fila(`IGV ${dec(c.igv_porcentaje).toString()}%`, c.igv, electronico);
  fila('ICBPER', c.icbper);
  const numero = numeroCompleto(c.serie, c.correlativo);

  return {
    plantilla: plantillaDe(empresa),
    formato: FORMATOS[formato],
    logo,
    qr_texto: electronico ? c.qr : null,
    datos: {
      emisor: emisorPdf(empresa, c.establecimiento_direccion, c.establecimiento_telefono),
      documento: {
        titulo: TITULOS[c.tipo],
        codigo: c.tipo,
        numero,
        fecha_emision: fecha(c.fecha_emision),
        hora_emision: c.hora_emision ? c.hora_emision.slice(0, 8) : null,
        fecha_vencimiento: null,
        moneda: c.moneda === 'USD' ? 'Dólares (US$)' : 'Soles (S/)',
        simbolo,
        tipo_cambio: c.tipo_cambio ? dec(c.tipo_cambio).toString() : null,
        forma_pago: esVenta ? (c.forma_pago === 'credito' ? 'Crédito' : 'Contado') : null,
        referencia: null,
        orden_compra: null,
        vendedor: c.tipo === '01' ? null : c.usuario_nombre,
        observaciones: null,
      },
      cliente: {
        etiqueta: c.tipo === '01' ? 'Adquiriente' : 'Cliente',
        nombre: c.cliente_nombre,
        documento_tipo: c.cliente_numero_documento ? (c.cliente_tipo_documento === '0' ? 'Doc.' : (NOMBRE_DOCUMENTO[c.cliente_tipo_documento] ?? 'Doc.')) : null,
        documento_numero: c.cliente_numero_documento || null,
        direccion: dato(c.cliente_direccion),
      },
      referencia: esNota
        ? {
            tipo: AFECTADOS[c.afectado_tipo ?? ''] ?? 'Comprobante',
            numero: c.afectado_serie && c.afectado_correlativo !== null ? numeroCompleto(c.afectado_serie, c.afectado_correlativo) : '',
            fecha: null,
            motivo: [c.motivo_codigo, c.motivo_descripcion].filter(Boolean).join(' - ') || null,
          }
        : null,
      columnas: { codigo: c.items.some((i) => dato(i.codigo)), descuento: c.items.some((i) => dec(i.descuento).gt(0)), precio: true },
      items: c.items.map((i, n) => ({
        n: n + 1,
        codigo: dato(i.codigo),
        descripcion: i.descripcion,
        unidad: (i.unidad || 'NIU').toUpperCase(),
        cantidad: sinCeros(i.cantidad),
        valor_unitario: esGratuito(i.afectacion) ? '0.00' : precio(i.valor_unitario),
        precio_unitario: esGratuito(i.afectacion) ? '0.00' : precio(i.precio_unitario),
        descuento: dec(i.descuento).gt(0) ? miles(i.descuento) : '',
        importe: esGratuito(i.afectacion) ? '0.00' : miles(i.total),
        afectacion: etiquetaAfectacion(i.afectacion),
      })),
      totales,
      total: miles(c.total),
      letras,
      cuotas: cuotas.map((q, i) => ({ n: String(i + 1).padStart(3, '0'), fecha: fecha(q.fecha_pago), monto: miles(q.monto) })),
      credito_pendiente: cuotas.length ? miles(cuotas.reduce((s, q) => s.add(dec(q.monto)), new Decimal(0)).toString()) : null,
      detraccion: conDetraccion
        ? {
            bien: c.detraccion?.codigo_bien_servicio ?? null,
            porcentaje: `${dec(c.detraccion?.porcentaje).toString()}%`,
            monto: `S/ ${miles(c.detraccion?.monto)}`,
            cuenta: c.detraccion?.cuenta_banco ?? null,
          }
        : null,
      leyendas: leyendas.filter((l) => l.codigo && l.codigo !== '1000' && l.valor && !(l.codigo === '2006' && conDetraccion)).map((l) => l.valor),
      medios: [],
      hash: electronico ? c.hash : null,
      representacion: REPRESENTACIONES[c.tipo],
      consulta: { sunat: electronico ? CONSULTA_SUNAT : null, web: null },
      texto_legal: null,
      color: '#1e293b',
      sello: selloDe(c.estado) ?? (electronico && c.entorno === 'beta' ? 'PRUEBA' : null),
    },
  };
}

export const NUMERO_POR_EMITIR = 'POR EMITIR';
const LEYENDA_VISTA_PREVIA = 'Vista previa, sin validez';
export const SELLO_VISTA_PREVIA = 'VISTA PREVIA';

export function peticionVistaPrevia(c: ComprobantePdf, empresa: EmpresaPdf, formato: FormatoPdf, logo: string | null): PeticionPdf {
  const base = peticionComprobante({ ...c, qr: null, hash: null }, empresa, formato, logo);
  return {
    ...base,
    qr_texto: null,
    datos: {
      ...base.datos,
      documento: { ...(base.datos.documento as Record<string, unknown>), numero: NUMERO_POR_EMITIR },
      hash: null,
      representacion: LEYENDA_VISTA_PREVIA,
      consulta: { sunat: null, web: null },
      vista_previa: true,
      texto_legal: LEYENDA_VISTA_PREVIA,
      sello: SELLO_VISTA_PREVIA,
    },
  };
}

type Par = [string, string];
const pares = (lista: [string, string | null | undefined | false][]): Par[] => lista.filter((p): p is Par => Boolean(p[1]));
const DOCUMENTO_CONDUCTOR: Record<string, string> = { '1': 'DNI', '4': 'C.E.', '7': 'Pasaporte' };

export function peticionGuia(g: GuiaPdf, empresa: EmpresaPdf, formato: FormatoPdf, logo: string | null): PeticionPdf {
  const publico = g.modalidad === '01';
  const m1l = Boolean(g.conductor?.vehiculo_m1l);
  const conductor = [g.conductor?.nombres, g.conductor?.apellidos].filter(Boolean).join(' ');
  const bloques = [
    {
      titulo: 'Datos del traslado',
      pares: pares([
        ['Fecha de emisión', fecha(g.fecha_emision)],
        ['Inicio del traslado', g.fecha_traslado ? fecha(g.fecha_traslado) : null],
        ['Motivo', MOTIVOS_TRASLADO[g.motivo_codigo ?? ''] ?? g.motivo_codigo],
        ['Modalidad', publico ? 'Transporte público' : m1l ? 'Transporte privado (vehículo M1 o L)' : 'Transporte privado'],
        ['Peso bruto', g.peso_total ? `${sinCeros(g.peso_total)} ${g.unidad_peso === 'TNE' ? 'TN' : 'KG'}` : null],
        ['Bultos', g.bultos ? String(g.bultos) : null],
        ['Doc. relacionado', g.relacionado],
      ]),
    },
    {
      titulo: 'Destinatario',
      pares: pares([
        ['Razón social', g.destinatario_nombre],
        [NOMBRE_DOCUMENTO[g.destinatario_tipo_documento ?? ''] ?? 'Doc.', g.destinatario_numero_documento],
      ]),
    },
    { titulo: 'Punto de partida', pares: pares([['Dirección', g.partida_direccion], ['Ubigeo', g.partida_ubigeo]]) },
    { titulo: 'Punto de llegada', pares: pares([['Dirección', g.llegada_direccion], ['Ubigeo', g.llegada_ubigeo]]) },
    publico
      ? { titulo: 'Transportista', pares: pares([['Razón social', g.transportista?.razon_social], ['RUC', g.transportista?.ruc], ['N.° MTC', g.transportista?.mtc]]) }
      : m1l
        ? null
        : {
            titulo: 'Vehículo y conductor',
            pares: pares([
              ['Placa', g.vehiculo_placa],
              ['Conductor', conductor],
              [DOCUMENTO_CONDUCTOR[g.conductor?.tipo_documento ?? '1'] ?? 'Doc.', g.conductor?.numero],
              ['Licencia', g.conductor?.licencia],
            ]),
          },
  ].filter((b): b is { titulo: string; pares: Par[] } => Boolean(b) && (b as { pares: Par[] }).pares.length > 0);

  return {
    plantilla: plantillaDe(empresa),
    formato: FORMATOS[formato],
    logo,
    qr_texto: g.qr,
    datos: {
      emisor: { ...emisorPdf(empresa, g.establecimiento_direccion), direccion: dato(g.establecimiento_direccion) ?? dato(empresa.direccion) },
      documento: { titulo: 'Guía de remisión electrónica remitente', numero: numeroCompleto(g.serie, g.correlativo) },
      bloques,
      items: g.items.map((i, k) => ({ n: k + 1, codigo: i.codigo ?? '', descripcion: i.descripcion, unidad: i.unidad, cantidad: sinCeros(i.cantidad) })),
      observaciones: null,
      hash: g.hash,
      representacion: 'Representación impresa de la Guía de Remisión Electrónica Remitente',
      sello: selloDe(g.estado) ?? (g.entorno === 'beta' ? 'PRUEBA' : null),
    },
  };
}
