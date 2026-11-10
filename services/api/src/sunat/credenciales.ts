import { ErrorDatosSunat, type CredencialesSunat } from './cliente.js';

export interface FilaConfiguracionSunat {
  entorno: 'beta' | 'produccion';
  usuario_sol: string | null;
  clave_sol_cifrada: string | null;
  certificado_cifrado: string | null;
  gre_client_id: string | null;
  gre_client_secret_cifrado: string | null;
  envio_boletas: 'individual' | 'resumen_diario';
}

export interface CredencialesDemo {
  usuario: string | undefined;
  clave: string | undefined;
}

type Descifrar = (texto: string) => string;

const SIN_CONFIGURAR = 'SUNAT_SIN_CONFIGURAR';

const abrir = (valor: string | null, descifrar: Descifrar): string | null => (valor ? descifrar(valor) : null);

export function resolverCredenciales(fila: FilaConfiguracionSunat, demo: CredencialesDemo, descifrar: Descifrar): CredencialesSunat {
  const certificado = abrir(fila.certificado_cifrado, descifrar);
  if (fila.entorno === 'produccion') {
    const clave_sol = abrir(fila.clave_sol_cifrada, descifrar);
    if (!fila.usuario_sol || !clave_sol || !certificado) {
      throw new ErrorDatosSunat(SIN_CONFIGURAR, 'Falta configurar el usuario SOL, la clave SOL o el certificado digital');
    }
    return {
      entorno: 'PRODUCCION',
      usuario_sol: fila.usuario_sol,
      clave_sol,
      certificado,
      certificado_clave: null,
      api_client_id: fila.gre_client_id,
      api_client_secret: abrir(fila.gre_client_secret_cifrado, descifrar),
    };
  }
  if (!demo.usuario || !demo.clave) {
    throw new ErrorDatosSunat(SIN_CONFIGURAR, 'Faltan SUNAT_DEMO_USUARIO o SUNAT_DEMO_CLAVE para el entorno beta');
  }
  return { entorno: 'PRUEBA', usuario_sol: demo.usuario, clave_sol: demo.clave, certificado, certificado_clave: null };
}

export function exigirCredencialesGuia(c: CredencialesSunat): CredencialesSunat {
  if (c.entorno === 'PRODUCCION' && (!c.api_client_id || !c.api_client_secret)) {
    throw new ErrorDatosSunat(SIN_CONFIGURAR, 'Para emitir guías falta el Client ID o el Client Secret de la API de SUNAT');
  }
  return c;
}
