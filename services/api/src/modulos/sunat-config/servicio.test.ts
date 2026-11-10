import { beforeEach, describe, expect, it, vi } from 'vitest';

type Llamada = { sql: string; params: unknown[] };

const estadoPrueba = vi.hoisted(() => ({
  llamadas: [] as Llamada[],
  config: { entorno: 'beta', usuario_sol: null as string | null, clave_sol_cifrada: null as string | null, certificado_cifrado: null as string | null },
  ruc: '20606883537' as string | null,
}));

vi.mock('../../db/pool.js', () => {
  const cliente = {
    query: async (sql: string, params: unknown[] = []) => {
      estadoPrueba.llamadas.push({ sql, params });
      if (sql.includes('from empresa')) return { rows: [{ ruc: estadoPrueba.ruc }] };
      if (sql.startsWith('select') && sql.includes('configuracion_sunat')) return { rows: [{ ...estadoPrueba.config, tiene: false }] };
      return { rows: [] };
    },
  };
  return { pool: cliente, withTransaction: async (fn: (c: typeof cliente) => unknown) => fn(cliente) };
});

vi.mock('../../sunat/config.js', () => ({ obtenerCredencialesSunat: async () => ({}) }));

const { cifrar } = await import('../../config/cifrado.js');
const { cambiarEntorno, eliminarCertificado, guardarCredenciales, interpretarPrueba } = await import('./servicio.js');

const USUARIO = '11111111-1111-1111-1111-111111111111';
const auditorias = () => estadoPrueba.llamadas.filter((l) => l.sql.includes('insert into auditoria'));
const actualizaciones = () => estadoPrueba.llamadas.filter((l) => l.sql.includes('update configuracion_sunat'));

beforeEach(() => {
  estadoPrueba.llamadas.length = 0;
  Object.assign(estadoPrueba.config, { entorno: 'beta', usuario_sol: null, clave_sol_cifrada: null, certificado_cifrado: null });
  estadoPrueba.ruc = '20606883537';
});

describe('credenciales SUNAT', () => {
  it('cifra los secretos y no los deja en la auditoría', async () => {
    await guardarCredenciales({ usuario_sol: 'USUARIO1', clave_sol: 'CLAVE-SECRETA', gre_client_secret: 'GRE-SECRETO', envio_boletas: 'individual' }, USUARIO);
    const [update] = actualizaciones();
    expect(JSON.stringify(update?.params)).not.toContain('CLAVE-SECRETA');
    expect(JSON.stringify(update?.params)).not.toContain('GRE-SECRETO');
    expect(auditorias()).toHaveLength(1);
    const detalle = String(auditorias()[0]?.params[4]);
    expect(detalle).not.toContain('CLAVE-SECRETA');
    expect(detalle).toContain('clave_sol_cambiada');
  });
});

describe('cambio de entorno', () => {
  it('no cambia ni audita si la confirmación del RUC falla', async () => {
    await expect(cambiarEntorno('produccion', '20100070970', USUARIO)).rejects.toMatchObject({ codigo: 'CONFIRMACION_RUC_INVALIDA' });
    expect(actualizaciones()).toHaveLength(0);
    expect(auditorias()).toHaveLength(0);
  });

  it('trata una clave SOL ilegible como ausente', async () => {
    estadoPrueba.config.usuario_sol = 'USUARIO1';
    estadoPrueba.config.clave_sol_cifrada = 'v1:dañado:x:y';
    estadoPrueba.config.certificado_cifrado = cifrar('pem');
    await expect(cambiarEntorno('produccion', '20606883537', USUARIO)).rejects.toMatchObject({ codigo: 'SUNAT_INCOMPLETO' });
  });

  it('volver a beta no exige confirmación y queda auditado', async () => {
    estadoPrueba.config.entorno = 'produccion';
    await cambiarEntorno('beta', undefined, USUARIO);
    expect(actualizaciones()).toHaveLength(1);
    expect(auditorias()[0]?.params[1]).toBe('SUNAT_ENTORNO_CAMBIADO');
  });

  it('impide eliminar el certificado en producción', async () => {
    estadoPrueba.config.entorno = 'produccion';
    await expect(eliminarCertificado(USUARIO)).rejects.toMatchObject({ codigo: 'EN_PRODUCCION' });
  });
});

describe('interpretarPrueba', () => {
  it('considera autenticado el código de ticket inexistente', () => {
    expect(interpretarPrueba('produccion', { firma: { ok: true }, sol: { codigo: '0127', mensaje: 'no existe' } }).ok).toBe(true);
  });

  it('marca credenciales rechazadas y firma fallida', () => {
    expect(interpretarPrueba('produccion', { firma: { ok: true }, sol: { codigo: '0102', mensaje: 'rechazado' } }).ok).toBe(false);
    expect(interpretarPrueba('beta', { firma: { ok: false, mensaje: 'x' }, sol: { codigo: '0127', mensaje: '' } }).ok).toBe(false);
  });
});
