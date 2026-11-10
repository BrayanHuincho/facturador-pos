import { describe, expect, it } from 'vitest';
import { cifrar, descifrar } from './cifrado.js';

describe('cifrado', () => {
  it('recupera el texto original y usa el formato v1:iv:tag:data', () => {
    const cifrado = cifrar('secreto ñandú');
    expect(cifrado.split(':')).toHaveLength(4);
    expect(cifrado.startsWith('v1:')).toBe(true);
    expect(cifrado).not.toContain('secreto');
    expect(descifrar(cifrado)).toBe('secreto ñandú');
  });

  it('genera un iv distinto en cada cifrado', () => {
    expect(cifrar('igual')).not.toBe(cifrar('igual'));
  });

  it('rechaza datos manipulados', () => {
    const [version, iv, tag, datos] = cifrar('importante').split(':') as [string, string, string, string];
    const alterado = Buffer.from(datos, 'base64url');
    alterado[0] = (alterado[0] ?? 0) ^ 0xff;
    expect(() => descifrar([version, iv, tag, alterado.toString('base64url')].join(':'))).toThrow();
  });

  it('rechaza formatos desconocidos', () => {
    expect(() => descifrar('v2:a:b:c')).toThrow();
    expect(() => descifrar('texto-plano')).toThrow();
  });
});
