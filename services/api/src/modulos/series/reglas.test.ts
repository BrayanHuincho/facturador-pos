import { describe, expect, it } from 'vitest';
import { errorSerie } from './reglas.js';

describe('errorSerie', () => {
  it('acepta las series por tipo', () => {
    for (const [tipo, serie] of [['01', 'F001'], ['03', 'B001'], ['07', 'FC01'], ['07', 'BC01'], ['08', 'BD01'], ['09', 'T001'], ['NV', 'NV01']] as const) {
      expect(errorSerie(tipo, serie)).toBeNull();
    }
  });

  it('rechaza prefijos o formatos incorrectos', () => {
    expect(errorSerie('01', 'B001')).not.toBeNull();
    expect(errorSerie('03', 'F001')).not.toBeNull();
    expect(errorSerie('07', 'XC01')).not.toBeNull();
    expect(errorSerie('09', 'F001')).not.toBeNull();
    expect(errorSerie('01', 'F01')).not.toBeNull();
    expect(errorSerie('01', 'f001')).not.toBeNull();
  });
});
