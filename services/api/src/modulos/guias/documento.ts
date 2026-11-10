import { Decimal } from 'decimal.js';
import { MOTIVOS_TRASLADO } from '../../sunat/catalogos.js';

export interface GuiaEnvio {
  id: string;
  serie: string;
  correlativo: number;
  fecha_emision: string;
  hora_emision: string | null;
  fecha_traslado: string;
  motivo_codigo: string;
  modalidad: string;
  peso_total: string;
  unidad_peso: string | null;
  bultos: number | null;
  partida_ubigeo: string;
  partida_direccion: string;
  llegada_ubigeo: string;
  llegada_direccion: string;
  destinatario_tipo_documento: string;
  destinatario_numero_documento: string;
  destinatario_nombre: string;
  transportista: { ruc?: string; razon_social?: string; mtc?: string | null } | null;
  conductor: { tipo_documento?: string; numero?: string; nombres?: string; apellidos?: string; licencia?: string; vehiculo_m1l?: boolean } | null;
  vehiculo_placa: string | null;
  estado: string;
  ticket: string | null;
  xml_path: string | null;
  cdr_path: string | null;
  entorno: 'beta' | 'produccion' | null;
  establecimiento_codigo: string | null;
  relacionado_tipo: string | null;
  relacionado_numero: string | null;
  items: { codigo: string | null; descripcion: string; unidad: string; cantidad: string }[];
}

export function documentoGuia(g: GuiaEnvio): Record<string, unknown> {
  const m1l = Boolean(g.conductor?.vehiculo_m1l);
  return {
    serie: g.serie,
    correlativo: String(g.correlativo),
    fecha_emision: g.fecha_emision,
    hora_emision: g.hora_emision ? g.hora_emision.slice(0, 8) : '',
    fecha_traslado: g.fecha_traslado,
    motivo: g.motivo_codigo,
    motivo_descripcion: MOTIVOS_TRASLADO[g.motivo_codigo] ?? null,
    modalidad: g.modalidad,
    vehiculo_m1l: m1l,
    peso_total: new Decimal(g.peso_total).toNumber(),
    unidad_peso: g.unidad_peso ?? 'KGM',
    bultos: g.bultos,
    destinatario: { tipo_documento: g.destinatario_tipo_documento, numero: g.destinatario_numero_documento, razon_social: g.destinatario_nombre },
    documento: g.relacionado_numero ? { tipo: g.relacionado_tipo ?? '01', descripcion: g.relacionado_tipo === '03' ? 'Boleta de venta' : 'Factura', numero: g.relacionado_numero } : null,
    partida: { ubigeo: g.partida_ubigeo, direccion: g.partida_direccion, cod_local: g.establecimiento_codigo && /^\d{4}$/.test(g.establecimiento_codigo) ? g.establecimiento_codigo : '0000' },
    llegada: { ubigeo: g.llegada_ubigeo, direccion: g.llegada_direccion },
    transportista: g.transportista?.ruc ? { ruc: g.transportista.ruc, razon_social: g.transportista.razon_social, mtc: g.transportista.mtc ?? null } : null,
    vehiculo_placa: g.vehiculo_placa,
    conductor: g.conductor?.numero
      ? { tipo_documento: g.conductor.tipo_documento ?? '1', numero: g.conductor.numero, nombres: g.conductor.nombres, apellidos: g.conductor.apellidos, licencia: g.conductor.licencia }
      : null,
    observaciones: null,
    items: g.items.map((i) => ({ codigo: i.codigo, descripcion: i.descripcion, unidad: i.unidad, cantidad: new Decimal(i.cantidad).toNumber() })),
  };
}

export interface DatosValidacionGuia {
  fecha_traslado: string;
  motivo_codigo: string;
  modalidad: '01' | '02';
  destinatario_numero_documento: string;
  partida_ubigeo: string;
  partida_direccion: string;
  llegada_ubigeo: string;
  llegada_direccion: string;
  transportista?: { ruc?: string; razon_social?: string } | null;
  conductor?: { numero?: string; nombres?: string; apellidos?: string; licencia?: string } | null;
  vehiculo_placa?: string | null;
  vehiculo_m1l?: boolean;
}

export function erroresGuia(g: DatosValidacionGuia, rucEmisor: string, hoy: string): string[] {
  const errores: string[] = [];
  if (g.fecha_traslado < hoy) errores.push('La fecha de inicio del traslado no puede ser anterior a hoy.');
  if (g.motivo_codigo === '04' && g.destinatario_numero_documento !== rucEmisor) errores.push('En un traslado entre establecimientos el destinatario es tu propia empresa.');
  if (g.motivo_codigo !== '04' && g.partida_ubigeo === g.llegada_ubigeo && g.partida_direccion.toUpperCase() === g.llegada_direccion.toUpperCase()) {
    errores.push('El punto de partida y el de llegada no pueden ser el mismo.');
  }
  if (g.motivo_codigo === '01' && g.destinatario_numero_documento === rucEmisor) errores.push('En una venta el destinatario es el cliente, no tu empresa.');
  if (g.modalidad === '01') {
    if (!g.transportista?.ruc || !g.transportista.razon_social) errores.push('En transporte público indica el RUC y la razón social del transportista.');
    if (g.transportista?.ruc === rucEmisor) errores.push('El transportista no puede ser tu propia empresa: usa transporte privado.');
  } else if (!g.vehiculo_m1l) {
    if (!g.vehiculo_placa) errores.push('En transporte privado indica la placa del vehículo.');
    if (!g.conductor?.numero || !g.conductor.nombres || !g.conductor.apellidos || !g.conductor.licencia) {
      errores.push('En transporte privado indica el documento, nombres, apellidos y licencia del conductor.');
    }
  }
  return errores;
}
