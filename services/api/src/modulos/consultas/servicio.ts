import { entorno } from '../../config/entorno.js';
import { ErrorApi } from '../../http/errores.js';
import { dniValido, rucValido } from './documento.js';

export type TipoConsulta = 'RUC' | 'DNI';

export type DatosDocumento = {
  tipo: TipoConsulta;
  numero: string;
  razon_social: string;
  direccion: string | null;
  ubigeo: string | null;
  distrito: string | null;
  provincia: string | null;
  departamento: string | null;
  estado: string | null;
  condicion: string | null;
};

type Crudo = Record<string, unknown>;

const MILISEGUNDOS_LIMITE = 8000;

const texto = (valor: unknown): string | null => {
  if (typeof valor !== 'string') return null;
  const limpio = valor.trim();
  return limpio && limpio !== '-' ? limpio : null;
};

export function normalizarRespuesta(tipo: TipoConsulta, numero: string, d: Crudo): DatosDocumento | null {
  if (tipo === 'DNI') {
    const completo =
      texto(d.full_name) ??
      texto(d.nombreCompleto) ??
      texto(d.nombre_completo) ??
      ([d.apellidoPaterno ?? d.apellido_paterno ?? d.first_last_name, d.apellidoMaterno ?? d.apellido_materno ?? d.second_last_name, d.nombres ?? d.first_name]
        .map(texto)
        .filter(Boolean)
        .join(' ') ||
        null);
    if (!completo) return null;
    return {
      tipo,
      numero,
      razon_social: completo.replace(/\s+/g, ' '),
      direccion: null,
      ubigeo: null,
      distrito: null,
      provincia: null,
      departamento: null,
      estado: null,
      condicion: null,
    };
  }
  const razon = texto(d.razon_social) ?? texto(d.razonSocial) ?? texto(d.nombre_o_razon_social) ?? texto(d.nombre);
  if (!razon) return null;
  const ubigeo = texto(d.ubigeo) ?? texto(d.ubigeo_sunat);
  return {
    tipo,
    numero,
    razon_social: razon,
    direccion: texto(d.direccion) ?? texto(d.direccion_completa),
    ubigeo: ubigeo && /^\d{6}$/.test(ubigeo) ? ubigeo : null,
    distrito: texto(d.distrito),
    provincia: texto(d.provincia),
    departamento: texto(d.departamento),
    estado: texto(d.estado) ?? texto(d.estado_del_contribuyente),
    condicion: texto(d.condicion) ?? texto(d.condicion_de_domicilio),
  };
}

export function tipoDeConsulta(tipo: string): TipoConsulta {
  const normalizado = tipo.toUpperCase();
  if (normalizado === 'RUC' || normalizado === '6') return 'RUC';
  if (normalizado === 'DNI' || normalizado === '1') return 'DNI';
  throw new ErrorApi(400, 'TIPO_DOCUMENTO_INVALIDO', 'Solo se consultan RUC y DNI.');
}

function validarNumero(tipo: TipoConsulta, numero: string) {
  if (tipo === 'RUC' && !rucValido(numero)) throw new ErrorApi(400, 'DOCUMENTO_INVALIDO', 'El RUC no es válido.');
  if (tipo === 'DNI' && !dniValido(numero)) throw new ErrorApi(400, 'DOCUMENTO_INVALIDO', 'El DNI tiene 8 dígitos.');
}

function urlProveedor(base: string, tipo: TipoConsulta, numero: string): string {
  if (/apiperu\.dev/i.test(base)) return `${base}/${tipo === 'RUC' ? 'ruc' : 'dni'}/${numero}`;
  return `${base}/${tipo === 'RUC' ? 'sunat/ruc' : 'reniec/dni'}?numero=${numero}`;
}

const consultaFallida = (mensaje: string) => new ErrorApi(502, 'CONSULTA_FALLIDA', mensaje);
const noEncontrado = (tipo: TipoConsulta, numero: string) => new ErrorApi(404, 'DOCUMENTO_NO_ENCONTRADO', `No se encontró el ${tipo} ${numero}.`);

export async function consultarDocumento(tipo: TipoConsulta, numero: string): Promise<DatosDocumento> {
  validarNumero(tipo, numero);
  const base = entorno.CONSULTA_DOCUMENTO_URL?.replace(/\/+$/, '');
  if (!base) {
    throw new ErrorApi(503, 'CONSULTA_NO_CONFIGURADA', 'La consulta de RUC/DNI no está configurada. Escribe los datos a mano.');
  }
  const token = entorno.CONSULTA_DOCUMENTO_TOKEN;
  let respuesta: Response;
  try {
    respuesta = await fetch(urlProveedor(base, tipo, numero), {
      headers: { Accept: 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      signal: AbortSignal.timeout(MILISEGUNDOS_LIMITE),
    });
  } catch {
    throw consultaFallida('El servicio de consulta no respondió. Inténtalo de nuevo o escribe los datos a mano.');
  }
  if (respuesta.status === 404 || respuesta.status === 422) throw noEncontrado(tipo, numero);
  if (!respuesta.ok) throw consultaFallida('El servicio de consulta devolvió un error. Escribe los datos a mano.');

  const cuerpo = (await respuesta.json().catch(() => null)) as Crudo | null;
  const datos = cuerpo && typeof cuerpo.data === 'object' && cuerpo.data ? (cuerpo.data as Crudo) : cuerpo;
  const normalizado = datos ? normalizarRespuesta(tipo, numero, datos) : null;
  if (!normalizado) throw noEncontrado(tipo, numero);
  return normalizado;
}
