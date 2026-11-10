export interface TipoImagen {
  extension: 'png' | 'jpg' | 'webp';
  mime: string;
}

const inicia = (datos: Buffer, firma: number[], desde = 0): boolean =>
  datos.length >= desde + firma.length && firma.every((byte, i) => datos[desde + i] === byte);

const PNG = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
const JPEG = [0xff, 0xd8, 0xff];
const RIFF = [0x52, 0x49, 0x46, 0x46];
const WEBP = [0x57, 0x45, 0x42, 0x50];

export function detectarImagen(datos: Buffer): TipoImagen | null {
  if (inicia(datos, PNG)) return { extension: 'png', mime: 'image/png' };
  if (inicia(datos, JPEG)) return { extension: 'jpg', mime: 'image/jpeg' };
  if (inicia(datos, RIFF) && inicia(datos, WEBP, 8)) return { extension: 'webp', mime: 'image/webp' };
  return null;
}
