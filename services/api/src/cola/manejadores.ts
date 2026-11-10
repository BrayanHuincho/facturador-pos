import { consultarGuia, enviarGuia, marcarFalloGuia, reencolarGuiasPendientes } from '../modulos/guias/servicio.js';
import {
  consultarTicket,
  encolarFirmasPendientes,
  enviarDocumentoTicket,
  generarResumenDiario,
  marcarFalloDocumento,
  programarResumenSiCorresponde,
  reencolarTicketsPendientes,
  type ClaseTicket,
} from '../modulos/resumenes/servicio.js';
import { depsEnvio } from '../sunat/datos.js';
import { enviarComprobante, marcarFalloEnvio } from '../sunat/envio.js';
import { ErrorDefinitivo } from './errores.js';
import type { Manejadores, Trabajo } from './motor.js';

function texto(t: Trabajo, ...claves: string[]): string | undefined {
  for (const clave of claves) {
    const valor = t.payload[clave];
    if (typeof valor === 'string' && valor) return valor;
  }
  return undefined;
}

function exigir(t: Trabajo, ...claves: string[]): string {
  const valor = texto(t, ...claves);
  if (!valor) throw new ErrorDefinitivo(`Al trabajo ${t.tipo} le falta ${claves[0]}`);
  return valor;
}

function claseTicket(t: Trabajo): { clase: ClaseTicket; id: string } {
  const baja = texto(t, 'baja_id');
  if (baja) return { clase: 'baja', id: baja };
  const resumen = texto(t, 'resumen_id');
  if (resumen) return { clase: 'resumen', id: resumen };
  return { clase: t.payload.clase === 'baja' ? 'baja' : 'resumen', id: exigir(t, 'id') };
}

export const manejadores: Manejadores = {
  enviar_comprobante: {
    ejecutar: (t) => enviarComprobante(exigir(t, 'comprobante_id', 'id'), depsEnvio),
    alAgotar: (t, mensaje) => marcarFalloEnvio(exigir(t, 'comprobante_id', 'id'), mensaje, depsEnvio),
  },
  enviar_resumen: {
    ejecutar: (t) => enviarDocumentoTicket('resumen', exigir(t, 'resumen_id', 'id')),
    alAgotar: (t, mensaje) => marcarFalloDocumento('resumen', exigir(t, 'resumen_id', 'id'), mensaje),
  },
  enviar_baja: {
    ejecutar: (t) => enviarDocumentoTicket('baja', exigir(t, 'baja_id', 'id')),
    alAgotar: (t, mensaje) => marcarFalloDocumento('baja', exigir(t, 'baja_id', 'id'), mensaje),
  },
  consultar_ticket: {
    ejecutar: (t) => {
      const { clase, id } = claseTicket(t);
      return consultarTicket(clase, id);
    },
  },
  enviar_guia: {
    ejecutar: (t) => enviarGuia(exigir(t, 'guia_id', 'id')),
    alAgotar: (t, mensaje) => marcarFalloGuia(exigir(t, 'guia_id', 'id'), mensaje),
  },
  consultar_guia: {
    ejecutar: (t) => consultarGuia(exigir(t, 'guia_id', 'id')),
  },
  generar_resumen_diario: {
    ejecutar: (t) => generarResumenDiario(texto(t, 'fecha')),
  },
};

export async function tareasPeriodicas(): Promise<void> {
  await reencolarTicketsPendientes();
  await reencolarGuiasPendientes();
}

export { encolarFirmasPendientes, programarResumenSiCorresponde };
