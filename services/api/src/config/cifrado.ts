import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { entorno } from './entorno.js';

const ALGORITMO = 'aes-256-gcm';
const VERSION = 'v1';
const BYTES_IV = 12;

function claveMaestra(): Buffer {
  return Buffer.from(entorno.CLAVE_CIFRADO, 'hex');
}

export function cifrar(texto: string): string {
  const iv = randomBytes(BYTES_IV);
  const cifrador = createCipheriv(ALGORITMO, claveMaestra(), iv);
  const datos = Buffer.concat([cifrador.update(texto, 'utf8'), cifrador.final()]);
  return [VERSION, iv.toString('base64url'), cifrador.getAuthTag().toString('base64url'), datos.toString('base64url')].join(':');
}

export function descifrar(texto: string): string {
  const [version, iv, tag, datos, sobrante] = texto.split(':');
  if (version !== VERSION || !iv || !tag || datos === undefined || sobrante !== undefined) {
    throw new Error('Valor cifrado con formato inválido');
  }
  const descifrador = createDecipheriv(ALGORITMO, claveMaestra(), Buffer.from(iv, 'base64url'));
  descifrador.setAuthTag(Buffer.from(tag, 'base64url'));
  return Buffer.concat([descifrador.update(Buffer.from(datos, 'base64url')), descifrador.final()]).toString('utf8');
}
