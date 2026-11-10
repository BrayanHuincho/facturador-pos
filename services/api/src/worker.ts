import { encolarFirmasPendientes, manejadores, programarResumenSiCorresponde, tareasPeriodicas } from './cola/manejadores.js';
import { mensajeDe, WorkerCola, type Registro } from './cola/motor.js';
import { pool } from './db/pool.js';

const CADA_MINUTO_MS = 60_000;
const CADA_CINCO_MINUTOS_MS = 5 * 60_000;

const log: Registro = {
  info: (mensaje) => console.info(mensaje),
  aviso: (mensaje) => console.warn(mensaje),
  error: (mensaje) => console.error(mensaje),
};

const worker = new WorkerCola(pool, manejadores, log);

async function protegido(nombre: string, tarea: () => Promise<unknown>): Promise<void> {
  try {
    await tarea();
  } catch (e) {
    log.error(`${nombre}: ${mensajeDe(e)}`);
  }
}

const cadaMinuto = () =>
  Promise.all([
    protegido('Recuperación de trabajos', () => worker.recuperar()),
    protegido('Programación del resumen diario', () => programarResumenSiCorresponde()),
    protegido('Firma de boletas por resumen', () => encolarFirmasPendientes()),
  ]);
const cadaCincoMinutos = () => protegido('Tareas periódicas', tareasPeriodicas);

async function principal(): Promise<void> {
  await cadaMinuto();
  await cadaCincoMinutos();
  worker.iniciar();
  log.info('Worker SUNAT iniciado');

  const temporizadores = [setInterval(() => void cadaMinuto(), CADA_MINUTO_MS), setInterval(() => void cadaCincoMinutos(), CADA_CINCO_MINUTOS_MS)];

  let apagando = false;
  const apagar = async (senal: string) => {
    if (apagando) return;
    apagando = true;
    log.info(`${senal}: terminando los trabajos en curso`);
    temporizadores.forEach(clearInterval);
    const limpio = await worker.detener();
    if (!limpio) log.aviso('Quedaron trabajos en curso: se recuperarán en el próximo arranque');
    await pool.end().catch(() => undefined);
    process.exit(0);
  };
  process.on('SIGTERM', () => void apagar('SIGTERM'));
  process.on('SIGINT', () => void apagar('SIGINT'));
}

principal().catch((e) => {
  log.error(`El worker no pudo arrancar: ${mensajeDe(e)}`);
  process.exit(1);
});
