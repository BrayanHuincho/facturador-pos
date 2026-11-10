import type { PoolClient } from 'pg';
import { descifrar } from '../config/cifrado.js';
import { entorno } from '../config/entorno.js';
import type { CredencialesSunat } from './cliente.js';
import { resolverCredenciales, type FilaConfiguracionSunat } from './credenciales.js';

type Consulta = Pick<PoolClient, 'query'>;

export async function leerConfiguracionSunat(c: Consulta): Promise<FilaConfiguracionSunat> {
  const { rows } = await c.query<FilaConfiguracionSunat>(
    `select entorno, usuario_sol, clave_sol_cifrada, certificado_cifrado, gre_client_id, gre_client_secret_cifrado, envio_boletas
       from configuracion_sunat where id = 1`,
  );
  return rows[0];
}

export async function obtenerCredencialesSunat(c: Consulta): Promise<CredencialesSunat> {
  const fila = await leerConfiguracionSunat(c);
  return resolverCredenciales(fila, { usuario: entorno.SUNAT_DEMO_USUARIO, clave: entorno.SUNAT_DEMO_CLAVE }, descifrar);
}
