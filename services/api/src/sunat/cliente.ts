import { ErrorDefinitivo, ErrorReintentable } from '../cola/errores.js';

export interface CredencialesSunat {
  entorno: 'PRUEBA' | 'PRODUCCION';
  usuario_sol: string | null;
  clave_sol: string | null;
  certificado: string | null;
  certificado_clave: string | null;
  api_client_id?: string | null;
  api_client_secret?: string | null;
}

export interface EmisorSunat {
  ruc: string;
  razon_social: string;
  nombre_comercial: string | null;
  direccion: string | null;
  ubigeo: string | null;
  departamento: string | null;
  provincia: string | null;
  distrito: string | null;
  cod_local: string;
}

export interface RespuestaSunat {
  exito: boolean;
  xml?: string | null;
  hash?: string | null;
  cdr?: string | null;
  codigo?: string | null;
  descripcion?: string | null;
  notas: string[];
  ticket?: string | null;
  estado_ticket?: string | null;
  error?: { codigo: string; mensaje: string; red?: boolean } | null;
  cdr_codigo?: string | null;
  cdr_descripcion?: string | null;
  pendiente?: boolean;
  qr?: string | null;
}

export type RutaGateway = 'factura' | 'nota' | 'resumen' | 'baja' | 'ticket' | 'consulta-cpe' | 'firmar' | 'probar' | 'guia' | 'guia-estado';

export interface CuerpoGateway {
  credenciales: CredencialesSunat;
  emisor: EmisorSunat;
  documento: unknown;
}

export type LlamarGateway = (ruta: RutaGateway, cuerpo: CuerpoGateway) => Promise<RespuestaSunat>;

export class ErrorRedSunat extends ErrorReintentable {
  constructor(mensaje: string, esperaBaseMs?: number) {
    super(mensaje, esperaBaseMs);
    this.name = 'ErrorRedSunat';
  }
}

export class ErrorDatosSunat extends ErrorDefinitivo {
  constructor(
    readonly codigo: string,
    mensaje: string,
  ) {
    super(mensaje);
    this.name = 'ErrorDatosSunat';
  }
}

export const LIMITE_GATEWAY_MS = 75_000;

export function crearLlamadaGateway(config: { url: string; token: string; limiteMs?: number }): LlamarGateway {
  const base = config.url.replace(/\/$/, '');
  return async (ruta, cuerpo) => {
    let respuesta: Response;
    try {
      respuesta = await fetch(`${base}/${ruta}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Token-Interno': config.token },
        body: JSON.stringify(cuerpo),
        signal: AbortSignal.timeout(config.limiteMs ?? LIMITE_GATEWAY_MS),
      });
    } catch (e) {
      throw new ErrorRedSunat(e instanceof Error && e.name === 'TimeoutError' ? 'SUNAT no respondió a tiempo' : 'El servicio SUNAT no está disponible');
    }
    const datos = (await respuesta.json().catch(() => null)) as RespuestaSunat | null;
    if (respuesta.status === 401) throw new ErrorDatosSunat('TOKEN_INTERNO', 'El token interno del gateway SUNAT no coincide');
    if (respuesta.status >= 500 || !datos) throw new ErrorRedSunat(`El servicio SUNAT respondió HTTP ${respuesta.status}`);
    if (respuesta.status === 400 || respuesta.status === 422) {
      throw new ErrorDatosSunat(datos.error?.codigo ?? 'DATOS', datos.error?.mensaje ?? 'Datos no válidos para SUNAT');
    }
    if (!datos.exito && datos.error?.red) throw new ErrorRedSunat(datos.error.mensaje);
    return { ...datos, notas: datos.notas ?? [] };
  };
}
