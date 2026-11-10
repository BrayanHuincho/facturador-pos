import { decimal, redondear, type Valor } from './dinero.js';

const UNIDADES = ['', 'UNO', 'DOS', 'TRES', 'CUATRO', 'CINCO', 'SEIS', 'SIETE', 'OCHO', 'NUEVE', 'DIEZ', 'ONCE', 'DOCE', 'TRECE', 'CATORCE', 'QUINCE', 'DIECISEIS', 'DIECISIETE', 'DIECIOCHO', 'DIECINUEVE', 'VEINTE', 'VEINTIUNO', 'VEINTIDOS', 'VEINTITRES', 'VEINTICUATRO', 'VEINTICINCO', 'VEINTISEIS', 'VEINTISIETE', 'VEINTIOCHO', 'VEINTINUEVE'];
const DECENAS = ['', '', '', 'TREINTA', 'CUARENTA', 'CINCUENTA', 'SESENTA', 'SETENTA', 'OCHENTA', 'NOVENTA'];
const CENTENAS = ['', 'CIENTO', 'DOSCIENTOS', 'TRESCIENTOS', 'CUATROCIENTOS', 'QUINIENTOS', 'SEISCIENTOS', 'SETECIENTOS', 'OCHOCIENTOS', 'NOVECIENTOS'];

function menorMil(n: number): string {
  if (n === 0) return '';
  if (n === 100) return 'CIEN';
  const centena = Math.floor(n / 100);
  const resto = n % 100;
  const texto = resto < 30 ? UNIDADES[resto] : DECENAS[Math.floor(resto / 10)] + (resto % 10 ? ` Y ${UNIDADES[resto % 10]}` : '');
  return [CENTENAS[centena], texto].filter(Boolean).join(' ');
}

function enteroEnLetras(n: number): string {
  if (n === 0) return 'CERO';
  const millones = Math.floor(n / 1_000_000);
  const miles = Math.floor((n % 1_000_000) / 1000);
  const resto = n % 1000;
  const partes: string[] = [];
  if (millones) partes.push(millones === 1 ? 'UN MILLON' : `${enteroEnLetras(millones)} MILLONES`);
  if (miles) partes.push(miles === 1 ? 'MIL' : `${menorMil(miles).replace(/UNO$/, 'UN')} MIL`);
  if (resto) partes.push(menorMil(resto));
  return partes.join(' ');
}

export function montoEnLetras(monto: Valor, moneda: 'PEN' | 'USD' = 'PEN'): string {
  const importe = redondear(decimal(monto));
  const entero = importe.floor().toNumber();
  const centimos = importe.sub(importe.floor()).mul(100).toNumber();
  const nombre = moneda === 'USD' ? 'DÓLARES AMERICANOS' : 'SOLES';
  return `SON: ${enteroEnLetras(entero)} CON ${String(Math.round(centimos)).padStart(2, '0')}/100 ${nombre}`;
}
