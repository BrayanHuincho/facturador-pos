#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const LIMITE_SALIDA_GIT = 256 * 1024 * 1024;
const EXIT_LIMPIO = 0;
const EXIT_HALLAZGOS = 1;
const EXIT_ERROR = 2;

const NOMBRES_PROHIBIDOS = [
  [/^\.env(?!\.example$)/, 'archivo de entorno'],
  [/^env\.json$/, 'configuración de Flutter con valores reales'],
  [/\.(pfx|p12|pem|key|p8|der|cer|crt)$/i, 'certificado o clave'],
  [/\.(jks|keystore)$/i, 'almacén de claves de Android'],
  [/^key\.properties$/, 'credenciales de firma de Android'],
  [/^id_(rsa|dsa|ecdsa|ed25519)$/, 'clave SSH privada'],
];

const PATRONES_DE_FORMATO = [
  [/-----BEGI[N] (?:[A-Z0-9]+ )*PRIVATE KEY/, 'clave privada PEM'],
  [/-----BEGI[N] CERTIFICATE-----/, 'certificado PEM'],
  [/\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/, 'JWT (clave de Supabase o token)'],
  [/\bsb_secre[t]_[A-Za-z0-9_-]{16,}/, 'clave secreta de Supabase'],
  [/\bsbp_[a-f0-9]{32,}/, 'token de acceso de Supabase'],
  [/\bAKI[A][0-9A-Z]{16}\b/, 'clave de AWS'],
  [/\bgh[pousr]_[A-Za-z0-9]{30,}/, 'token de GitHub'],
  [/\bgithub_pa[t]_[A-Za-z0-9_]{30,}/, 'token de GitHub'],
  [/\bxox[abprs]-[A-Za-z0-9-]{10,}/, 'token de Slack'],
  [/\bAIz[a][A-Za-z0-9_-]{35}\b/, 'clave de Google'],
  [/\bsk_liv[e]_[A-Za-z0-9]{16,}/, 'clave de Stripe'],
  [/\bsk-(?:ant-|proj-)?[A-Za-z0-9_-]{32,}/, 'clave de API de IA'],
  [/\bMOD[D]ATOS\b/i, 'credencial demo de SUNAT escrita en el código'],
];

const VALOR_DE_MUESTRA =
  /^(?:\$|<|\{\{|%|env\()|ejemplo|example|placeholder|cambia|changeme|reemplaza|replace|dummy|fake|falso|prueba|test|xxx|\*\*\*|tu[-_]|your[-_]|process\.env|platform\.environment|secrets\./i;

const URL_CON_CLAVE =
  /\b(?:postgres(?:ql)?|mysql|redis|mongodb(?:\+srv)?):\/\/[^:\s/'"`]+:([^@\s'"`]+)@([^:/\s'"`]+)/g;
const HOST_LOCAL = /^(?:localhost|127\.0\.0\.1|host\.docker\.internal|db|postgres)$/i;

const ASIGNACION_ENTRE_COMILLAS =
  /\b[A-Za-z0-9_$-]*(?:secret|password|passwd|pwd|token|api[_-]?key|clave|contrasena)[A-Za-z0-9_$-]*["']?\s*(?:=>|=|:)\s*["'`]([^"'`\s]{10,})["'`]/gi;
const NOMBRE_DE_VARIABLE_SENSIBLE =
  '[A-Z0-9_]*(?:SECRET|PASSWORD|PASSWD|TOKEN|API_?KEY|CLAVE|SERVICE_ROLE|ANON_KEY)[A-Z0-9_]*';
const ASIGNACION_DE_CONFIG = new RegExp(
  `\\b${NOMBRE_DE_VARIABLE_SENSIBLE}["']?[ \\t]*[=:][ \\t]*["']?([^\\s"'#,]{8,})`,
  'g',
);
const ASIGNACION_DE_SHELL = new RegExp(`\\b${NOMBRE_DE_VARIABLE_SENSIBLE}=["']?([^\\s"'#,]{8,})`, 'g');

const EXTENSIONES_DE_CONFIG = new Set(['.yml', '.yaml', '.toml', '.properties', '.ini', '.conf', '.json']);
const EXTENSIONES_DE_TEXTO_LIBRE = new Set(['.md', '.txt', '.sh', '.ps1']);

function git(argumentos, opciones = {}) {
  return execFileSync('git', argumentos, {
    cwd: RAIZ,
    maxBuffer: LIMITE_SALIDA_GIT,
    stdio: ['ignore', 'pipe', 'pipe'],
    ...opciones,
  });
}

function separarRutas(salida) {
  return [...new Set(salida.toString('utf8').split('\0').filter(Boolean))];
}

function raizEsRepositorio() {
  try {
    return git(['rev-parse', '--show-cdup']).toString('utf8').trim() === '';
  } catch {
    return false;
  }
}

function listarSinRepositorio() {
  const temporal = mkdtempSync(join(tmpdir(), 'escaneo-secretos-'));
  try {
    git(['init', '-q', temporal]);
    return separarRutas(
      git([
        `--git-dir=${join(temporal, '.git')}`,
        `--work-tree=${RAIZ}`,
        'ls-files',
        '-z',
        '--others',
        '--exclude-standard',
      ]),
    );
  } finally {
    rmSync(temporal, { recursive: true, force: true });
  }
}

function listarArchivos(soloPreparados) {
  if (!raizEsRepositorio()) {
    if (soloPreparados) throw new Error('--staged requiere un repositorio git');
    return listarSinRepositorio();
  }
  if (soloPreparados) {
    return separarRutas(git(['diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z']));
  }
  return separarRutas(git(['ls-files', '-z', '--cached', '--others', '--exclude-standard']));
}

function leerContenido(ruta, soloPreparados) {
  if (soloPreparados) return git(['show', `:${ruta}`]);
  const absoluta = join(RAIZ, ruta);
  if (!existsSync(absoluta) || !statSync(absoluta).isFile()) return null;
  return readFileSync(absoluta);
}

function esBinario(contenido) {
  return contenido.subarray(0, 8000).includes(0);
}

function esValorReal(valor) {
  return !VALOR_DE_MUESTRA.test(valor) && !valor.includes('${');
}

function parecePorEntropia(valor) {
  return /[A-Za-z]/.test(valor) && /[0-9]/.test(valor);
}

function reglasDeAsignacion(ruta) {
  const nombre = basename(ruta);
  const extension = extname(nombre).toLowerCase();
  if (nombre.startsWith('.env') || EXTENSIONES_DE_CONFIG.has(extension)) return ASIGNACION_DE_CONFIG;
  if (EXTENSIONES_DE_TEXTO_LIBRE.has(extension)) return ASIGNACION_DE_SHELL;
  return null;
}

function esArchivoDePrueba(ruta) {
  return /(?:\.(?:test|spec)\.[cm]?[jt]s|_test\.dart|(?:^|\/)vitest\.config\.[cm]?[jt]s)$/.test(ruta);
}

function esDemoPublicaDeBeta(ruta, linea) {
  return ruta === 'scripts/levantar-local.ps1' && /MOD[D]ATOS/i.test(linea);
}

function revisarLinea(linea, asignacionDeConfig, omitirAsignacionesEnCodigo) {
  const motivos = [];
  for (const [patron, motivo] of PATRONES_DE_FORMATO) {
    if (patron.test(linea)) motivos.push(motivo);
  }
  for (const coincidencia of linea.matchAll(URL_CON_CLAVE)) {
    if (esValorReal(coincidencia[1]) && !HOST_LOCAL.test(coincidencia[2])) {
      motivos.push('URL de base de datos con contraseña');
    }
  }
  if (!omitirAsignacionesEnCodigo) {
    for (const coincidencia of linea.matchAll(ASIGNACION_ENTRE_COMILLAS)) {
      if (esValorReal(coincidencia[1]) && parecePorEntropia(coincidencia[1])) {
        motivos.push('secreto asignado en el código');
      }
    }
  }
  if (asignacionDeConfig) {
    for (const coincidencia of linea.matchAll(asignacionDeConfig)) {
      if (esValorReal(coincidencia[1])) motivos.push('valor real en variable sensible');
    }
  }
  return [...new Set(motivos)];
}

function revisarArchivo(ruta, soloPreparados) {
  const hallazgos = [];
  const nombre = basename(ruta);
  for (const [patron, motivo] of NOMBRES_PROHIBIDOS) {
    if (patron.test(nombre)) hallazgos.push({ ruta, linea: null, motivo });
  }
  const contenido = leerContenido(ruta, soloPreparados);
  if (!contenido || esBinario(contenido)) return hallazgos;
  const asignacionDeConfig = reglasDeAsignacion(ruta);
  contenido
    .toString('utf8')
    .split(/\r?\n/)
    .forEach((linea, indice) => {
      for (const motivo of esDemoPublicaDeBeta(ruta, linea) ? [] : revisarLinea(linea, asignacionDeConfig, esArchivoDePrueba(ruta))) {
        hallazgos.push({ ruta, linea: indice + 1, motivo });
      }
    });
  return hallazgos;
}

function principal() {
  const soloPreparados = process.argv.includes('--staged');
  const archivos = listarArchivos(soloPreparados);
  const hallazgos = archivos.flatMap((ruta) => revisarArchivo(ruta, soloPreparados));
  if (hallazgos.length === 0) {
    console.log(`Sin secretos en ${archivos.length} archivos revisados.`);
    return EXIT_LIMPIO;
  }
  console.error(`Se encontraron ${hallazgos.length} posibles secretos. No hagas commit:`);
  for (const { ruta, linea, motivo } of hallazgos) {
    console.error(`  ${ruta}${linea ? `:${linea}` : ''}  ${motivo}`);
  }
  return EXIT_HALLAZGOS;
}

try {
  process.exitCode = principal();
} catch (error) {
  console.error(`No se pudo completar el escaneo: ${error.message}`);
  process.exitCode = EXIT_ERROR;
}
