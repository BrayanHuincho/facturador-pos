export type EstadoFinal = 'aceptado' | 'observado' | 'rechazado' | 'error';
export type ClaseCodigo = 'ACEPTADO' | 'TRANSITORIO' | 'CREDENCIALES' | 'YA_PRESENTADO' | 'RECHAZO' | 'OBSERVACION' | 'ERROR';

export const NOMBRE_DOCUMENTO: Record<string, string> = { '0': 'Sin documento', '1': 'DNI', '4': 'Carné de extranjería', '6': 'RUC', '7': 'Pasaporte' };

export const MOTIVOS_TRASLADO: Record<string, string> = {
  '01': 'Venta',
  '14': 'Venta sujeta a confirmación del comprador',
  '02': 'Compra',
  '04': 'Traslado entre establecimientos de la misma empresa',
  '06': 'Devolución',
  '07': 'Recojo de bienes transformados',
  '05': 'Consignación',
  '17': 'Traslado de bienes para transformación',
  '13': 'Otros',
};

export const numeroCompleto = (serie: string, correlativo: number | string): string => `${serie}-${String(correlativo).padStart(6, '0')}`;

const TRANSITORIOS = new Set(['0100', '0109', '0130', '0131', '0132', '0133', '0134', '0135', '0136', '0137', '0138', '0200', '0201', '0202', '0203', '0204', 'HTTP']);
const DE_CREDENCIALES = new Set(['0101', '0102', '0103', '0104', '0105', '0106', '0110', '0111', '0112', '0113', '0114']);

export function codigoLimpio(codigo: unknown): string | null {
  if (codigo === null || codigo === undefined) return null;
  const texto = String(codigo).trim();
  const numero = /(\d{1,4})\s*$/.exec(texto)?.[1];
  if (!numero) return texto || null;
  return Number(numero) === 0 ? '0' : numero.padStart(4, '0');
}

export function claseDeCodigo(codigo: unknown): ClaseCodigo {
  const c = codigoLimpio(codigo);
  if (c === null) return 'ERROR';
  if (c === '0') return 'ACEPTADO';
  if (TRANSITORIOS.has(c)) return 'TRANSITORIO';
  if (DE_CREDENCIALES.has(c)) return 'CREDENCIALES';
  if (c === '1033') return 'YA_PRESENTADO';
  const n = /^\d+$/.test(c) ? Number(c) : NaN;
  if (n >= 4000) return 'OBSERVACION';
  if (n >= 2000) return 'RECHAZO';
  return 'ERROR';
}

export function estadoPorCodigo(codigo: unknown, exito: boolean): EstadoFinal {
  const c = codigoLimpio(codigo);
  if (exito && c === null) return 'aceptado';
  const n = c !== null && /^\d+$/.test(c) ? Number(c) : NaN;
  if (Number.isNaN(n)) return 'error';
  if (n === 0) return 'aceptado';
  if (n >= 4000) return 'observado';
  if (n >= 2000) return 'rechazado';
  return 'error';
}

export function explicarCodigo(codigo: unknown): string | null {
  const c = codigoLimpio(codigo);
  if (c === null) return null;
  const clase = claseDeCodigo(c);
  if (clase === 'TRANSITORIO') return 'SUNAT no pudo procesar el envío en este momento. Se reintenta automáticamente.';
  if (clase === 'CREDENCIALES') return 'SUNAT no aceptó el usuario o la clave SOL, o el usuario no tiene el perfil de emisor electrónico.';
  if (clase === 'YA_PRESENTADO') return 'SUNAT ya tiene un comprobante con este número. Verifícalo en la Consulta de comprobantes de SUNAT antes de anularlo.';
  if (c === '0127') return 'SUNAT no encuentra el ticket.';
  if (c === '2335') return 'El XML fue alterado tras firmarlo: revisa que el certificado sea el del RUC emisor.';
  if (c === '2800') return 'El tipo de documento del cliente no está permitido para este comprobante.';
  return null;
}
