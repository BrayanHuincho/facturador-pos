import type { PoolClient } from 'pg';
import { cifrar, descifrar } from '../../config/cifrado.js';
import { entorno as variables } from '../../config/entorno.js';
import { registrarAuditoria } from '../../db/auditoria.js';
import { pool, withTransaction } from '../../db/pool.js';
import { ErrorApi } from '../../http/errores.js';
import { obtenerCredencialesSunat } from '../../sunat/config.js';
import { leerCertificado } from './certificado.js';
import { validarCertificadoParaEmpresa, validarPasoProduccion } from './reglas.js';

export type EntornoSunat = 'beta' | 'produccion';
export type EnvioBoletas = 'individual' | 'resumen_diario';

export type DatosCredenciales = {
  usuario_sol: string;
  clave_sol?: string;
  gre_client_id?: string;
  gre_client_secret?: string;
  envio_boletas: EnvioBoletas;
};

type FilaEstado = {
  entorno: EntornoSunat;
  usuario_sol: string | null;
  tiene_clave_sol: boolean;
  tiene_certificado: boolean;
  certificado_vence_en: Date | null;
  certificado_titular: string | null;
  tiene_gre: boolean;
  envio_boletas: EnvioBoletas;
};

type FilaEmpresaEmisor = {
  ruc: string | null;
  razon_social: string | null;
  nombre_comercial: string | null;
  direccion: string | null;
  ubigeo: string | null;
  departamento: string | null;
  provincia: string | null;
  distrito: string | null;
};

type Consultor = Pick<PoolClient, 'query'>;

const ENTIDAD = 'configuracion_sunat';
const MILISEGUNDOS_LIMITE_GATEWAY = 75_000;
const CODIGOS_SOL_AUTENTICADO = new Set(['0', '125', '126', '127']);

const SQL_ESTADO = `select entorno, usuario_sol,
    clave_sol_cifrada is not null as tiene_clave_sol,
    certificado_cifrado is not null as tiene_certificado,
    certificado_vence_en, certificado_titular,
    gre_client_id is not null and gre_client_secret_cifrado is not null as tiene_gre,
    envio_boletas
  from configuracion_sunat where id = 1`;

async function leerEstado(c: Consultor): Promise<FilaEstado> {
  const { rows } = await c.query<FilaEstado>(SQL_ESTADO);
  if (!rows[0]) throw new ErrorApi(500, 'CONFIGURACION_AUSENTE', 'No existe la configuración SUNAT.');
  return rows[0];
}

async function rucEmpresa(c: Consultor): Promise<string | null> {
  const { rows } = await c.query<{ ruc: string | null }>('select ruc from empresa where id = 1');
  return rows[0]?.ruc ?? null;
}

function descifrarOpcional(valor: string | null): string | null {
  if (!valor) return null;
  try {
    return descifrar(valor);
  } catch {
    return null;
  }
}

export function obtenerEstado(): Promise<FilaEstado> {
  return leerEstado(pool);
}

export async function guardarCredenciales(datos: DatosCredenciales, usuarioId: string): Promise<FilaEstado> {
  return withTransaction(async (c) => {
    const { rows } = await c.query<{ usuario_sol: string | null; envio_boletas: EnvioBoletas }>(
      'select usuario_sol, envio_boletas from configuracion_sunat where id = 1 for update',
    );
    await c.query(
      `update configuracion_sunat set
         usuario_sol = $1,
         clave_sol_cifrada = coalesce($2, clave_sol_cifrada),
         gre_client_id = coalesce($3, gre_client_id),
         gre_client_secret_cifrado = coalesce($4, gre_client_secret_cifrado),
         envio_boletas = $5,
         actualizado_en = now()
       where id = 1`,
      [
        datos.usuario_sol,
        datos.clave_sol === undefined ? null : cifrar(datos.clave_sol),
        datos.gre_client_id ?? null,
        datos.gre_client_secret === undefined ? null : cifrar(datos.gre_client_secret),
        datos.envio_boletas,
      ],
    );
    await registrarAuditoria(c, {
      usuarioId,
      accion: 'SUNAT_CREDENCIALES_CAMBIADAS',
      entidad: ENTIDAD,
      detalle: {
        usuario_sol_antes: rows[0]?.usuario_sol ?? null,
        usuario_sol_despues: datos.usuario_sol,
        envio_boletas_antes: rows[0]?.envio_boletas ?? null,
        envio_boletas_despues: datos.envio_boletas,
        clave_sol_cambiada: datos.clave_sol !== undefined,
        gre_client_id_cambiado: datos.gre_client_id !== undefined,
        gre_client_secret_cambiado: datos.gre_client_secret !== undefined,
      },
    });
    return leerEstado(c);
  });
}

export async function subirCertificado(archivo: Buffer, clave: string, usuarioId: string, ahora = new Date()): Promise<FilaEstado> {
  const leido = leerCertificado(archivo, clave);
  return withTransaction(async (c) => {
    await c.query('select id from configuracion_sunat where id = 1 for update');
    const ruc = await rucEmpresa(c);
    if (!ruc) throw new ErrorApi(409, 'EMPRESA_NO_CONFIGURADA', 'Registra primero los datos de la empresa.');
    validarCertificadoParaEmpresa(leido, ruc, ahora);
    await c.query(
      `update configuracion_sunat set certificado_cifrado = $1, certificado_vence_en = $2, certificado_titular = $3, actualizado_en = now() where id = 1`,
      [cifrar(leido.pem), leido.vence_en, leido.titular],
    );
    await registrarAuditoria(c, {
      usuarioId,
      accion: 'SUNAT_CERTIFICADO_SUBIDO',
      entidad: ENTIDAD,
      detalle: { titular: leido.titular, serie: leido.serie, ruc: leido.ruc, vence_en: leido.vence_en.toISOString() },
    });
    return leerEstado(c);
  });
}

export async function eliminarCertificado(usuarioId: string): Promise<FilaEstado> {
  return withTransaction(async (c) => {
    const { rows } = await c.query<{ entorno: EntornoSunat; tiene: boolean; certificado_titular: string | null }>(
      'select entorno, certificado_cifrado is not null as tiene, certificado_titular from configuracion_sunat where id = 1 for update',
    );
    if (rows[0]?.entorno === 'produccion') {
      throw new ErrorApi(409, 'EN_PRODUCCION', 'En producción no se puede quedar sin certificado: sube otro para reemplazarlo.');
    }
    if (rows[0]?.tiene) {
      await c.query(
        'update configuracion_sunat set certificado_cifrado = null, certificado_vence_en = null, certificado_titular = null, actualizado_en = now() where id = 1',
      );
      await registrarAuditoria(c, {
        usuarioId,
        accion: 'SUNAT_CERTIFICADO_ELIMINADO',
        entidad: ENTIDAD,
        detalle: { titular: rows[0].certificado_titular },
      });
    }
    return leerEstado(c);
  });
}

export async function cambiarEntorno(destino: EntornoSunat, confirmarRuc: string | undefined, usuarioId: string, ahora = new Date()): Promise<FilaEstado> {
  return withTransaction(async (c) => {
    const { rows } = await c.query<{
      entorno: EntornoSunat;
      usuario_sol: string | null;
      clave_sol_cifrada: string | null;
      certificado_cifrado: string | null;
    }>('select entorno, usuario_sol, clave_sol_cifrada, certificado_cifrado from configuracion_sunat where id = 1 for update');
    const actual = rows[0];
    if (!actual) throw new ErrorApi(500, 'CONFIGURACION_AUSENTE', 'No existe la configuración SUNAT.');
    if (actual.entorno === destino) return leerEstado(c);
    const ruc = await rucEmpresa(c);
    if (destino === 'produccion') {
      validarPasoProduccion({
        rucEmpresa: ruc,
        confirmarRuc,
        usuarioSol: actual.usuario_sol,
        tieneClaveSol: Boolean(descifrarOpcional(actual.clave_sol_cifrada)),
        pemCertificado: descifrarOpcional(actual.certificado_cifrado),
        ahora,
      });
    }
    await c.query('update configuracion_sunat set entorno = $1, actualizado_en = now() where id = 1', [destino]);
    await registrarAuditoria(c, {
      usuarioId,
      accion: 'SUNAT_ENTORNO_CAMBIADO',
      entidad: ENTIDAD,
      detalle: { antes: actual.entorno, despues: destino, ruc },
    });
    return leerEstado(c);
  });
}

export type PasoPrueba = { paso: string; ok: boolean; detalle: string };
export type ResultadoPrueba = { ok: boolean; entorno: EntornoSunat; pasos: PasoPrueba[]; mensaje: string };

type RespuestaProbar = {
  firma?: { ok: boolean; mensaje?: string | null } | null;
  sol?: { codigo: string | null; mensaje: string | null } | null;
  error?: { codigo: string; mensaje: string } | null;
};

export function codigoSolNormalizado(codigo: string | null | undefined): string | null {
  const digitos = /(\d+)\s*$/.exec(codigo ?? '')?.[1];
  return digitos === undefined ? null : String(Number(digitos));
}

export function interpretarPrueba(entornoActual: EntornoSunat, respuesta: RespuestaProbar): ResultadoPrueba {
  const firmaOk = Boolean(respuesta.firma?.ok);
  const codigo = codigoSolNormalizado(respuesta.sol?.codigo);
  const solOk = codigo !== null && CODIGOS_SOL_AUTENTICADO.has(codigo);
  const pasos: PasoPrueba[] = [
    {
      paso: 'Certificado digital',
      ok: firmaOk,
      detalle: firmaOk ? 'Abre y firma un XML de prueba.' : (respuesta.firma?.mensaje ?? respuesta.error?.mensaje ?? 'No se pudo firmar.'),
    },
    {
      paso: entornoActual === 'beta' ? 'Conexión con el beta de SUNAT' : 'Usuario y clave SOL',
      ok: solOk,
      detalle: solOk ? 'SUNAT atendió la consulta con estas credenciales.' : (respuesta.sol?.mensaje ?? respuesta.error?.mensaje ?? 'Sin respuesta de SUNAT.'),
    },
  ];
  const ok = firmaOk && solOk;
  return { ok, entorno: entornoActual, pasos, mensaje: ok ? 'Conexión correcta. No se emitió ningún comprobante.' : 'Revisa los pasos marcados con error.' };
}

export async function probarConexion(): Promise<ResultadoPrueba> {
  const { estado, credenciales, emisor } = await withTransaction(async (c) => {
    const { rows } = await c.query<FilaEmpresaEmisor>(
      'select ruc, razon_social, nombre_comercial, direccion, ubigeo, departamento, provincia, distrito from empresa where id = 1',
    );
    const empresa = rows[0];
    if (!empresa?.ruc) throw new ErrorApi(409, 'EMPRESA_NO_CONFIGURADA', 'Registra primero los datos de la empresa.');
    return { estado: await leerEstado(c), credenciales: await obtenerCredencialesSunat(c), emisor: { ...empresa, cod_local: '0000' } };
  });

  let respuesta: Response;
  try {
    respuesta = await fetch(`${variables.SUNAT_GATEWAY_URL}/probar`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Token-Interno': variables.SUNAT_GATEWAY_TOKEN },
      body: JSON.stringify({ credenciales, emisor, documento: {} }),
      signal: AbortSignal.timeout(MILISEGUNDOS_LIMITE_GATEWAY),
    });
  } catch {
    return {
      ok: false,
      entorno: estado.entorno,
      pasos: [{ paso: 'Servicio de firma', ok: false, detalle: 'El gateway SUNAT no respondió.' }],
      mensaje: 'No se pudo hablar con el servicio SUNAT. Intenta en unos minutos.',
    };
  }
  const cuerpo = (await respuesta.json().catch(() => null)) as RespuestaProbar | null;
  if (respuesta.status === 401 || !cuerpo) {
    return {
      ok: false,
      entorno: estado.entorno,
      pasos: [{ paso: 'Servicio de firma', ok: false, detalle: `El gateway respondió HTTP ${respuesta.status}.` }],
      mensaje: 'No se pudo hablar con el servicio SUNAT. Intenta en unos minutos.',
    };
  }
  return interpretarPrueba(estado.entorno, cuerpo);
}
