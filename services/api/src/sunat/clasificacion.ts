import { claseDeCodigo, codigoLimpio, estadoPorCodigo, type EstadoFinal } from './catalogos.js';
import type { RespuestaSunat } from './cliente.js';

export type Decision = { tipo: 'final'; estado: EstadoFinal } | { tipo: 'reintentar' } | { tipo: 'recuperar_cdr' };

export const codigoDeRespuesta = (r: RespuestaSunat): string | null => codigoLimpio(r.codigo ?? r.error?.codigo);

export function clasificarRespuesta(r: RespuestaSunat): Decision {
  const codigo = codigoDeRespuesta(r);
  if (r.exito) return { tipo: 'final', estado: estadoPorCodigo(codigo, true) };
  const clase = claseDeCodigo(codigo);
  if (clase === 'TRANSITORIO') return { tipo: 'reintentar' };
  if (clase === 'YA_PRESENTADO') return { tipo: 'recuperar_cdr' };
  return { tipo: 'final', estado: estadoPorCodigo(codigo, false) === 'aceptado' ? 'error' : estadoPorCodigo(codigo, false) };
}

export type DecisionTicket = { tipo: 'en_proceso' } | { tipo: 'reintentar' } | { tipo: 'final'; estado: EstadoFinal };

export function decidirTicket(r: RespuestaSunat): DecisionTicket {
  if (r.pendiente || codigoLimpio(r.estado_ticket) === '0098') return { tipo: 'en_proceso' };
  if (r.cdr) return { tipo: 'final', estado: estadoPorCodigo(r.codigo, true) };
  const decision = clasificarRespuesta(r);
  if (decision.tipo === 'reintentar') return { tipo: 'reintentar' };
  if (decision.tipo === 'recuperar_cdr') return { tipo: 'final', estado: 'error' };
  return decision;
}

export function textoDeRespuesta(r: RespuestaSunat): string | null {
  return r.descripcion ?? r.error?.mensaje ?? null;
}
