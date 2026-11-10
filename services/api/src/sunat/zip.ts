import { inflateRawSync } from 'node:zlib';

export interface ArchivoZip {
  nombre: string;
  datos: Buffer;
}

const FIRMA_FIN = 0x06054b50;
const FIRMA_CENTRAL = 0x02014b50;
const FIRMA_LOCAL = 0x04034b50;
const FIRMA_PARTIDO = 0x08074b50;

export const esZip = (b: Buffer): boolean => b.length >= 4 && (b.readUInt32LE(0) === FIRMA_LOCAL || b.readUInt32LE(0) === FIRMA_PARTIDO);

export function leerZip(b: Buffer): ArchivoZip[] {
  let fin = -1;
  for (let i = b.length - 22; i >= Math.max(0, b.length - 22 - 0xffff); i--) {
    if (b.readUInt32LE(i) === FIRMA_FIN) {
      fin = i;
      break;
    }
  }
  if (fin < 0) throw new Error('ZIP sin directorio central');

  const entradas = b.readUInt16LE(fin + 10);
  let p = b.readUInt32LE(fin + 16);
  const archivos: ArchivoZip[] = [];
  for (let n = 0; n < entradas; n++) {
    if (b.readUInt32LE(p) !== FIRMA_CENTRAL) throw new Error('ZIP dañado');
    const metodo = b.readUInt16LE(p + 10);
    const comprimido = b.readUInt32LE(p + 20);
    const largoNombre = b.readUInt16LE(p + 28);
    const largoExtra = b.readUInt16LE(p + 30);
    const largoComentario = b.readUInt16LE(p + 32);
    const local = b.readUInt32LE(p + 42);
    const nombre = b.toString('utf8', p + 46, p + 46 + largoNombre);
    p += 46 + largoNombre + largoExtra + largoComentario;
    if (nombre.endsWith('/')) continue;
    if (b.readUInt32LE(local) !== FIRMA_LOCAL) throw new Error('ZIP dañado');
    const inicio = local + 30 + b.readUInt16LE(local + 26) + b.readUInt16LE(local + 28);
    const crudo = b.subarray(inicio, inicio + comprimido);
    if (metodo === 0) archivos.push({ nombre, datos: Buffer.from(crudo) });
    else if (metodo === 8) archivos.push({ nombre, datos: inflateRawSync(crudo) });
    else throw new Error(`Compresión ZIP no soportada: ${metodo}`);
  }
  return archivos;
}
