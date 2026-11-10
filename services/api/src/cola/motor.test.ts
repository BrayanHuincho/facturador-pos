import { describe, expect, it, vi } from 'vitest';
import { ErrorDefinitivo, ErrorReintentable } from './errores.js';
import { calcularEsperaMs, destinoDelFallo, procesarTrabajo, reclamarTrabajo, recuperarBloqueados, WorkerCola, type BaseDatosCola, type Manejadores, type Registro, type Trabajo } from './motor.js';

const log: Registro = { info: () => undefined, aviso: () => undefined, error: () => undefined };
const trabajo = (parcial: Partial<Trabajo> = {}): Trabajo => ({ id: 't1', tipo: 'enviar_comprobante', payload: {}, estado: 'procesando', intentos: 1, max_intentos: 7, ...parcial });
const baseFalsa = () => {
  const query = vi.fn(async (_texto: string, _valores?: unknown[]) => ({ rows: [] as unknown[], rowCount: 1 }));
  return { query } as BaseDatosCola & { query: typeof query };
};
const con = (ejecutar: () => Promise<unknown>, alAgotar = vi.fn(async () => undefined)) => ({ manejadores: { enviar_comprobante: { ejecutar, alAgotar } } as unknown as Manejadores, alAgotar });

describe('reintentos', () => {
  it('20 s exponencial durante 7 intentos', () => {
    expect([1, 2, 3, 4, 5, 6].map((n) => calcularEsperaMs(n) / 1000)).toEqual([20, 40, 80, 160, 320, 640]);
  });

  it('reintenta hasta agotar y no reintenta lo definitivo', () => {
    expect(destinoDelFallo({ intentos: 2, max_intentos: 7 }, new ErrorReintentable('x'))).toEqual({ accion: 'reintentar', esperaMs: 40_000 });
    expect(destinoDelFallo({ intentos: 7, max_intentos: 7 }, new ErrorReintentable('x'))).toEqual({ accion: 'fallar', agotado: true });
    expect(destinoDelFallo({ intentos: 1, max_intentos: 7 }, new ErrorDefinitivo('x'))).toEqual({ accion: 'fallar', agotado: false });
    expect(destinoDelFallo({ intentos: 2, max_intentos: 7 }, new ErrorReintentable('x', 3_000))).toEqual({ accion: 'reintentar', esperaMs: 6_000 });
  });
});

describe('procesar', () => {
  it('reclama con FOR UPDATE SKIP LOCKED', async () => {
    const db = baseFalsa();
    await reclamarTrabajo(db);
    expect(db.query.mock.calls[0][0]).toMatch(/for update skip locked/);
  });

  it('marca hecho con cercado por intentos', async () => {
    const db = baseFalsa();
    const { manejadores } = con(async () => undefined);
    await procesarTrabajo(db, manejadores, trabajo({ intentos: 3 }), log);
    expect(db.query.mock.calls[0][0]).toMatch(/'hecho'/);
    expect(db.query.mock.calls[0][1]).toEqual(['t1', 3]);
  });

  it('programa el reintento sin avisar agotamiento', async () => {
    const db = baseFalsa();
    const { manejadores, alAgotar } = con(async () => { throw new ErrorReintentable('red'); });
    await procesarTrabajo(db, manejadores, trabajo(), log);
    expect(db.query.mock.calls[0][1]).toEqual(['t1', 1, 'red', 20_000]);
    expect(alAgotar).not.toHaveBeenCalled();
  });

  it('al agotar avisa al manejador y falla', async () => {
    const db = baseFalsa();
    const { manejadores, alAgotar } = con(async () => { throw new ErrorReintentable('red'); });
    await procesarTrabajo(db, manejadores, trabajo({ intentos: 7 }), log);
    expect(alAgotar).toHaveBeenCalledOnce();
    expect(db.query.mock.calls[0][0]).toMatch(/'fallido'/);
  });

  it('un error definitivo falla sin avisar agotamiento', async () => {
    const db = baseFalsa();
    const { manejadores, alAgotar } = con(async () => { throw new ErrorDefinitivo('datos'); });
    await procesarTrabajo(db, manejadores, trabajo(), log);
    expect(alAgotar).not.toHaveBeenCalled();
    expect(db.query.mock.calls[0][0]).toMatch(/'fallido'/);
  });
});

describe('recuperación y apagado', () => {
  it('recupera bloqueados vencidos y notifica los agotados', async () => {
    const db = baseFalsa();
    db.query.mockResolvedValueOnce({ rows: [trabajo({ estado: 'fallido', intentos: 7 }), trabajo({ id: 't2', estado: 'pendiente', intentos: 2 })], rowCount: 2 });
    const { manejadores, alAgotar } = con(async () => undefined);
    expect(await new WorkerCola(db, manejadores, log).recuperar()).toBe(2);
    expect(alAgotar).toHaveBeenCalledOnce();
    expect(db.query.mock.calls[0][0]).toMatch(/for update skip locked/);
  });

  it('el umbral supera el límite del gateway', async () => {
    const db = baseFalsa();
    await recuperarBloqueados(db);
    expect((db.query.mock.calls[0][1] as number[])[0]).toBeGreaterThan(75_000);
  });

  it('apagado: deja de reclamar y espera el trabajo en curso', async () => {
    const db = baseFalsa();
    let liberar: () => void = () => undefined;
    const enCurso = new Promise<void>((listo) => { liberar = listo; });
    db.query.mockResolvedValueOnce({ rows: [trabajo()], rowCount: 1 });
    const inicio = vi.fn(() => enCurso);
    const { manejadores } = con(inicio);
    const worker = new WorkerCola(db, manejadores, log, { concurrencia: 1, pausaSinTrabajoMs: 5, esperaApagadoMs: 2_000 });
    worker.iniciar();
    await vi.waitFor(() => expect(inicio).toHaveBeenCalled());
    const detenido = worker.detener();
    liberar();
    expect(await detenido).toBe(true);
    expect(db.query.mock.calls.some(([texto]) => /'hecho'/.test(texto))).toBe(true);
  });

  it('apagado: vence el plazo si el trabajo no termina', async () => {
    const db = baseFalsa();
    db.query.mockResolvedValueOnce({ rows: [trabajo()], rowCount: 1 });
    const { manejadores } = con(() => new Promise(() => undefined));
    const worker = new WorkerCola(db, manejadores, log, { concurrencia: 1, esperaApagadoMs: 10 });
    worker.iniciar();
    await vi.waitFor(() => expect(db.query).toHaveBeenCalled());
    expect(await worker.detener()).toBe(false);
  });
});
