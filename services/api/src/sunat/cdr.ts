import { codigoLimpio } from './catalogos.js';
import { esZip, leerZip } from './zip.js';

function xmlDelCdr(cdrBase64: string): string {
  const bytes = Buffer.from(cdrBase64, 'base64');
  return esZip(bytes) ? (leerZip(bytes).find((a) => /\.xml$/i.test(a.nombre))?.datos.toString('utf8') ?? '') : bytes.toString('utf8');
}

export function clienteDelCdr(cdrBase64: string): string | null {
  try {
    const parte = /<cac:RecipientParty>([\s\S]*?)<\/cac:RecipientParty>/.exec(xmlDelCdr(cdrBase64))?.[1];
    const id = parte ? /<cbc:ID[^>]*>\s*([^<]+?)\s*<\/cbc:ID>/.exec(parte)?.[1] : null;
    return id ? (id.split('-').pop() ?? id).trim() : null;
  } catch {
    return null;
  }
}

export function codigoDelCdr(cdrBase64: string): string | null {
  try {
    const codigo = /<cbc:ResponseCode[^>]*>\s*([^<]+?)\s*<\/cbc:ResponseCode>/.exec(xmlDelCdr(cdrBase64))?.[1];
    return codigo ? codigoLimpio(codigo) : null;
  } catch {
    return null;
  }
}

export function cdrDeOtroComprobante(cdrBase64: string, clienteNumero: string | null | undefined): boolean | null {
  const delCdr = clienteDelCdr(cdrBase64);
  if (!delCdr) return null;
  const propio = (clienteNumero ?? '').trim();
  if (!propio || /^0+$/.test(propio) || /^[0-]$/.test(delCdr)) return null;
  return delCdr !== propio;
}

export function extensionCdr(cdrBase64: string): 'zip' | 'xml' {
  return esZip(Buffer.from(cdrBase64.slice(0, 16), 'base64')) ? 'zip' : 'xml';
}
