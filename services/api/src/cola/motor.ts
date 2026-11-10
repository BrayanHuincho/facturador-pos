import { ErrorDefinitivo, ErrorReintentable } from './errores.js';
import type { TipoTrabajo } from './encolar.js';

export const ESPERA_BASE_MS = 20_000;
export const BLOQUEO_VENCIDO_MS = 5 * 60_000;
export const ESPERA_APAGADO_MS = 90_000;
const PAUSA_SIN_TRABAJO_MS = 1_000;
const PAUSA_TRAS_ERROR_MS = 5_000;

export interface Trabajo {
  id: string;
  tipo: TipoTrabajo;
  payload: Record<string, unknown>;
  estado: string;
  intentos: number;
  max_intentos: number;
}

export interface BaseDatosCola {
  query(texto: string, valores?: unknown[]): Promise<{ rows: any[]; rowCount: number | null }>;
}

export interface Manejador {
  ejecutar(trabajo: Trabajo): Promise<unknown>;
  alAgotar?(trabajo: Trabajo, mensaje: string): Promise<void>;
}

export type Manejadores = Record<TipoTrabajo, Manejador>;

export interface Registro {
  info(mensaje: string): void;
  aviso(mensaje: string): void;
  error(mensaje: string): void;
}

export type Destino = { accion: 'reintentar'; esperaMs: number } | { accion: 'fallar'; agotado: boolean };

export function calcularEsperaMs(intentos: number, baseMs = ESPERA_BASE_MS): number {
  return baseMs * 2 ** Math.max(0, intentos - 1);
}

export function destinoDelFallo(trabajo: Pick<Trabajo, 'intentos' | 'max_intentos'>, error: unknown): Destino {
  if (error instanceof ErrorDefinitivo) return { accion: 'fallar', agotado: false };
  if (trabajo.intentos >= trabajo.max_intentos) return { accion: 'fallar', agotado: true };
  const base = error instanceof ErrorReintentable ? error.esperaBaseMs : undefined;
  return { accion: 'reintentar', esperaMs: calcularEsperaMs(trabajo.intentos, base) };
}

export const mensajeDe = (e: unknown): string => (e instanceof Error ? e.message : String(e));

const COLUMNAS = 't.id, t.tipo, t.payload, t.estado, t.intentos, t.max_intentos';

export async function reclamarTrabajo(db: BaseDatosCola): Promise<Trabajo | null> {
  const { rows } = await db.query(
    `update trabajos t
        set estado = 'procesando', bloqueado_en = now(), intentos = t.intentos + 1
       from (
         select id from trabajos
          where estado = 'pendiente' and ejecutar_en <= now()
          order by ejecutar_en, creado_en
          limit 1
          for update skip locked
       ) siguiente
      where t.id = siguiente.id
      returning ${COLUMNAS}`,
  );
  return (rows[0] as Trabajo | undefined) ?? null;
}

export async function marcarHecho(db: BaseDatosCola, t: Trabajo): Promise<void> {
  await db.query(
    `update trabajos set estado = 'hecho', bloqueado_en = null, ultimo_error = null
      where id = $1 and estado = 'procesando' and intentos = $2`,
    [t.id, t.intentos],
  );
}

export async function programarReintento(db: BaseDatosCola, t: Trabajo, esperaMs: number, mensaje: string): Promise<void> {
  await db.query(
    `update trabajos
        set estado = 'pendiente', bloqueado_en = null, ultimo_error = $3,
            ejecutar_en = now() + ($4::double precision * interval '1 millisecond')
      where id = $1 and estado = 'procesando' and intentos = $2`,
    [t.id, t.intentos, mensaje, esperaMs],
  );
}

export async function marcarFallido(db: BaseDatosCola, t: Trabajo, mensaje: string): Promise<void> {
  await db.query(
    `update trabajos set estado = 'fallido', bloqueado_en = null, ultimo_error = $3
      where id = $1 and estado = 'procesando' and intentos = $2`,
    [t.id, t.intentos, mensaje],
  );
}

export async function recuperarBloqueados(db: BaseDatosCola, vencidoMs = BLOQUEO_VENCIDO_MS): Promise<Trabajo[]> {
  const { rows } = await db.query(
    `update trabajos t
        set estado = case when t.intentos >= t.max_intentos then 'fallido' else 'pendiente' end,
            bloqueado_en = null,
            ultimo_error = 'Recuperado tras una caída del worker',
            ejecutar_en = now() + (($2::double precision * power(2, greatest(t.intentos - 1, 0))) * interval '1 millisecond')
       from (
         select id from trabajos
          where estado = 'procesando'
            and bloqueado_en < now() - ($1::double precision * interval '1 millisecond')
          for update skip locked
       ) vencido
      where t.id = vencido.id
      returning ${COLUMNAS}`,
    [vencidoMs, ESPERA_BASE_MS],
  );
  return rows as Trabajo[];
}

async function notificarAgotado(manejador: Manejador | undefined, t: Trabajo, mensaje: string, log: Registro): Promise<void> {
  try {
    await manejador?.alAgotar?.(t, mensaje);
  } catch (e) {
    log.error(`${t.tipo} ${t.id} al agotar reintentos: ${mensajeDe(e)}`);
  }
}

export async function procesarTrabajo(db: BaseDatosCola, manejadores: Manejadores, t: Trabajo, log: Registro): Promise<void> {
  const manejador = manejadores[t.tipo];
  try {
    if (!manejador) throw new ErrorDefinitivo(`Tipo de trabajo desconocido: ${t.tipo}`);
    await manejador.ejecutar(t);
    await marcarHecho(db, t);
  } catch (e) {
    const mensaje = mensajeDe(e);
    const destino = destinoDelFallo(t, e);
    if (destino.accion === 'reintentar') {
      log.aviso(`${t.tipo} ${t.id} intento ${t.intentos}/${t.max_intentos}: ${mensaje}`);
      await programarReintento(db, t, destino.esperaMs, mensaje);
      return;
    }
    log.error(`${t.tipo} ${t.id} fallido: ${mensaje}`);
    if (destino.agotado) await notificarAgotado(manejador, t, mensaje, log);
    await marcarFallido(db, t, mensaje);
  }
}

export interface OpcionesWorker {
  concurrencia?: number;
  esperaApagadoMs?: number;
  pausaSinTrabajoMs?: number;
}

export class WorkerCola {
  private activo = false;
  private bucles: Promise<void>[] = [];
  private readonly despertadores = new Set<() => void>();

  constructor(
    private readonly db: BaseDatosCola,
    private readonly manejadores: Manejadores,
    private readonly log: Registro,
    private readonly opciones: OpcionesWorker = {},
  ) {}

  async recuperar(): Promise<number> {
    const recuperados = await recuperarBloqueados(this.db);
    for (const t of recuperados) {
      if (t.estado === 'fallido') await notificarAgotado(this.manejadores[t.tipo], t, 'El worker se cayó en el último intento', this.log);
    }
    return recuperados.length;
  }

  iniciar(): void {
    if (this.activo) return;
    this.activo = true;
    this.bucles = Array.from({ length: this.opciones.concurrencia ?? 3 }, () => this.bucle());
  }

  async detener(): Promise<boolean> {
    this.activo = false;
    for (const despertar of [...this.despertadores]) despertar();
    let temporizador: NodeJS.Timeout | undefined;
    const limite = new Promise<boolean>((listo) => {
      temporizador = setTimeout(() => listo(false), this.opciones.esperaApagadoMs ?? ESPERA_APAGADO_MS);
    });
    const limpio = await Promise.race([Promise.all(this.bucles).then(() => true), limite]);
    clearTimeout(temporizador);
    return limpio;
  }

  private async bucle(): Promise<void> {
    while (this.activo) {
      try {
        const trabajo = await reclamarTrabajo(this.db);
        if (!trabajo) {
          await this.dormir(this.opciones.pausaSinTrabajoMs ?? PAUSA_SIN_TRABAJO_MS);
          continue;
        }
        await procesarTrabajo(this.db, this.manejadores, trabajo, this.log);
      } catch (e) {
        this.log.error(`Bucle de la cola: ${mensajeDe(e)}`);
        await this.dormir(PAUSA_TRAS_ERROR_MS);
      }
    }
  }

  private dormir(ms: number): Promise<void> {
    return new Promise((listo) => {
      const terminar = () => {
        clearTimeout(temporizador);
        this.despertadores.delete(terminar);
        listo();
      };
      const temporizador = setTimeout(terminar, ms);
      this.despertadores.add(terminar);
    });
  }
}
