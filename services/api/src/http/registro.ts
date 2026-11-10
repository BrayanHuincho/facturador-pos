const CAMPOS_SENSIBLES = [
  'authorization',
  'cookie',
  'password',
  'clave',
  'clave_sol',
  'clave_sol_cifrada',
  'certificado',
  'certificado_cifrado',
  'certificado_clave',
  'gre_client_secret',
  'gre_client_secret_cifrado',
  'x-token-interno',
  'token',
  'access_token',
  'refresh_token',
];

const RUTAS_FIJAS = [
  'req.headers.authorization',
  'req.headers.cookie',
  'req.headers["x-token-interno"]',
  'res.headers["set-cookie"]',
  'err.config.headers',
];

function rutaCampo(campo: string): string {
  return /^[a-z_]+$/.test(campo) ? campo : `["${campo}"]`;
}

function rutaHija(prefijo: string, campo: string): string {
  return campo.includes('-') ? `${prefijo}["${campo}"]` : `${prefijo}.${campo}`;
}

export const rutasRedactadas = [
  ...RUTAS_FIJAS,
  ...CAMPOS_SENSIBLES.flatMap((campo) => [rutaCampo(campo), rutaHija('*', campo), rutaHija('*.*', campo)]),
];

export const opcionesRegistro = (nivel: string) => ({
  level: nivel,
  redact: { paths: rutasRedactadas, censor: '[REDACTADO]' },
});
