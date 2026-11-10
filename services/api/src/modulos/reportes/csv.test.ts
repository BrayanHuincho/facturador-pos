import { Decimal } from 'decimal.js';
import { describe, expect, it } from 'vitest';
import { escaparCelda, generarCsv, neutralizarFormula } from './csv.js';

describe('neutralizarFormula', () => {
  it.each(['=1+1', '+51', '-2', '@SUM(A1)', '\t=1', '\r=1', '\n=1', '  =1', '＝1', '＋1', '－1', '＠1'])(
    'antepone apóstrofo a %j',
    (texto) => {
      expect(neutralizarFormula(texto)).toBe(`'${texto}`);
    },
  );

  it('respeta el texto normal', () => {
    expect(neutralizarFormula('Bodega a=b')).toBe('Bodega a=b');
  });
});

describe('escaparCelda', () => {
  it('entrecomilla separadores y saltos de línea', () => {
    expect(escaparCelda('a,b')).toBe('"a,b"');
    expect(escaparCelda('a;b')).toBe('"a;b"');
    expect(escaparCelda('a\nb')).toBe('"a\nb"');
    expect(escaparCelda('a\r\nb')).toBe('"a\r\nb"');
  });

  it('duplica comillas internas', () => {
    expect(escaparCelda('dijo "hola"')).toBe('"dijo ""hola"""');
  });

  it('neutraliza y además escapa una fórmula con comillas', () => {
    expect(escaparCelda('=HYPERLINK("http://x","y")')).toBe('"\'=HYPERLINK(""http://x"",""y"")"');
  });

  it('deja vacíos los nulos', () => {
    expect(escaparCelda(null)).toBe('');
    expect(escaparCelda(undefined)).toBe('');
  });

  it('no altera importes negativos', () => {
    expect(escaparCelda(new Decimal('-10.5'))).toBe('-10.50');
    expect(escaparCelda(-3)).toBe('-3');
  });

  it('neutraliza un negativo recibido como texto', () => {
    expect(escaparCelda('-10.50')).toBe("'-10.50");
  });
});

describe('generarCsv', () => {
  it('genera BOM, CRLF y filas escapadas', () => {
    const csv = generarCsv(['a', 'b'], [['x,y', new Decimal('1')], ['=z', null]]);
    expect(csv).toBe('﻿a,b\r\n"x,y",1.00\r\n\'=z,\r\n');
  });
});
