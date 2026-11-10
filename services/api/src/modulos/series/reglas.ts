export const TIPOS_SERIE = ['01', '03', '07', '08', '09', 'NV'] as const;
export type TipoSerie = (typeof TIPOS_SERIE)[number];

export function errorSerie(tipo: TipoSerie, serie: string): string | null {
  if (!/^[A-Z0-9]{4}$/.test(serie)) return 'La serie tiene 4 caracteres: letras mayúsculas y números (F001, B001, FC01).';
  const letra = serie[0];
  if (tipo === '01' && letra !== 'F') return 'Las series de factura empiezan por F (F001).';
  if (tipo === '03' && letra !== 'B') return 'Las series de boleta empiezan por B (B001).';
  if ((tipo === '07' || tipo === '08') && letra !== 'F' && letra !== 'B') {
    return 'Las notas empiezan por F si modifican facturas (FC01) o por B si modifican boletas (BC01).';
  }
  if (tipo === '09' && letra !== 'T') return 'Las series de guía de remisión empiezan por T (T001).';
  return null;
}
