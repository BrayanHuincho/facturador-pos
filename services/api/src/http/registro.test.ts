import { Writable } from 'node:stream';
import Fastify from 'fastify';
import { describe, expect, it } from 'vitest';
import { rutasRedactadas } from './registro.js';

function registrar(objeto: Record<string, unknown>): string {
  let salida = '';
  const destino = new Writable({
    write(fragmento, _codificacion, listo) {
      salida += String(fragmento);
      listo();
    },
  });
  const app = Fastify({ logger: { level: 'info', stream: destino, redact: { paths: rutasRedactadas, censor: '[REDACTADO]' } } });
  app.log.info(objeto, 'evento');
  return salida;
}

describe('redacción de registros', () => {
  it('oculta secretos en primer, segundo y tercer nivel', () => {
    const salida = registrar({
      clave_sol: 'SECRETO-A',
      credenciales: { clave_sol: 'SECRETO-B', certificado: 'SECRETO-C' },
      cuerpo: { credenciales: { gre_client_secret: 'SECRETO-D' } },
      req: { headers: { authorization: 'Bearer SECRETO-E', 'x-token-interno': 'SECRETO-F' } },
      usuario_sol: 'VISIBLE',
    });
    expect(salida).not.toMatch(/SECRETO-/);
    expect(salida).toContain('VISIBLE');
  });
});
