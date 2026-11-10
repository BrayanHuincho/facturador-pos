import { Decimal } from 'decimal.js';
import { pool } from '../../db/pool.js';
import { formatearImporte } from '../caja/calculos.js';
import {
  FACTOR_CAMBIO_SQL,
  SIGNO_NOTA_CREDITO_SQL as SIGNO_SQL,
  TIPOS_CON_MOVIMIENTO_DE_PAGO,
} from '../caja/repositorio.js';
import type { TotalPorTipo } from './calculos.js';
import type { CeldaCsv } from './csv.js';

export const ESTADOS_EXCLUIDOS = ['anulado', 'por_anular', 'rechazado'];

export type Agrupacion = 'dia' | 'producto' | 'medio' | 'usuario';

export interface FiltroReporte {
  desde: string;
  hasta: string;
  usuarioId: string | null;
}

export interface FilaVentas {
  clave: string | null;
  etiqueta: string | null;
  documentos: number;
  total: string;
  cantidad?: string;
}

const CONDICION_BASE = `c.fecha_emision BETWEEN $1::date AND $2::date
  AND c.estado::text <> ALL($3::text[])
  AND ($4::uuid IS NULL OR c.usuario_id = $4::uuid)`;

const TOTAL_NETO_SQL = `SUM(${SIGNO_SQL} * ROUND(c.total * ${FACTOR_CAMBIO_SQL}, 2))`;

function parametros(filtro: FiltroReporte): unknown[] {
  return [filtro.desde, filtro.hasta, ESTADOS_EXCLUIDOS, filtro.usuarioId];
}

export async function consultarTotalesPorTipo(filtro: FiltroReporte): Promise<TotalPorTipo[]> {
  const { rows } = await pool.query<TotalPorTipo>(
    `SELECT c.tipo::text AS tipo,
            COUNT(*)::int AS documentos,
            SUM(ROUND(c.total * ${FACTOR_CAMBIO_SQL}, 2))::text AS total,
            SUM(ROUND(c.igv * ${FACTOR_CAMBIO_SQL}, 2))::text AS igv
       FROM comprobantes c
      WHERE ${CONDICION_BASE}
      GROUP BY c.tipo`,
    parametros(filtro),
  );
  return rows;
}

async function consultarPorDia(filtro: FiltroReporte): Promise<FilaVentas[]> {
  const { rows } = await pool.query<FilaVentas>(
    `SELECT to_char(c.fecha_emision, 'YYYY-MM-DD') AS clave,
            to_char(c.fecha_emision, 'YYYY-MM-DD') AS etiqueta,
            COUNT(*)::int AS documentos,
            ${TOTAL_NETO_SQL}::text AS total
       FROM comprobantes c
      WHERE ${CONDICION_BASE}
      GROUP BY c.fecha_emision
      ORDER BY c.fecha_emision`,
    parametros(filtro),
  );
  return rows;
}

async function consultarPorUsuario(filtro: FiltroReporte): Promise<FilaVentas[]> {
  const { rows } = await pool.query<FilaVentas>(
    `SELECT c.usuario_id::text AS clave,
            pe.nombre AS etiqueta,
            COUNT(*)::int AS documentos,
            ${TOTAL_NETO_SQL}::text AS total
       FROM comprobantes c
       LEFT JOIN perfiles pe ON pe.id = c.usuario_id
      WHERE ${CONDICION_BASE}
      GROUP BY c.usuario_id, pe.nombre
      ORDER BY ${TOTAL_NETO_SQL} DESC`,
    parametros(filtro),
  );
  return rows;
}

async function consultarPorProducto(filtro: FiltroReporte): Promise<FilaVentas[]> {
  const totalItems = `SUM(${SIGNO_SQL} * ROUND(i.total * ${FACTOR_CAMBIO_SQL}, 2))`;
  const { rows } = await pool.query<FilaVentas>(
    `SELECT i.producto_id::text AS clave,
            COALESCE(p.nombre, i.descripcion) AS etiqueta,
            COUNT(DISTINCT c.id)::int AS documentos,
            SUM(${SIGNO_SQL} * i.cantidad)::text AS cantidad,
            ${totalItems}::text AS total
       FROM comprobante_items i
       JOIN comprobantes c ON c.id = i.comprobante_id
       LEFT JOIN productos p ON p.id = i.producto_id
      WHERE ${CONDICION_BASE}
      GROUP BY i.producto_id, COALESCE(p.nombre, i.descripcion)
      ORDER BY ${totalItems} DESC`,
    parametros(filtro),
  );
  return rows;
}

async function consultarPorMedio(filtro: FiltroReporte): Promise<FilaVentas[]> {
  const pagos = await pool.query<{ medio: string; documentos: number; total: string }>(
    `SELECT p.medio::text AS medio,
            COUNT(DISTINCT c.id)::int AS documentos,
            SUM(${SIGNO_SQL} * ROUND(p.monto * ${FACTOR_CAMBIO_SQL}, 2))::text AS total
       FROM pagos p
       JOIN comprobantes c ON c.id = p.comprobante_id
      WHERE ${CONDICION_BASE} AND c.tipo::text = ANY($5::text[])
      GROUP BY p.medio
      ORDER BY p.medio`,
    [...parametros(filtro), TIPOS_CON_MOVIMIENTO_DE_PAGO],
  );
  return pagos.rows.map((fila) => ({
    clave: fila.medio,
    etiqueta: fila.medio,
    documentos: fila.documentos,
    total: formatearImporte(fila.total),
  }));
}

export function consultarVentas(filtro: FiltroReporte, agrupar: Agrupacion): Promise<FilaVentas[]> {
  const consultas: Record<Agrupacion, (f: FiltroReporte) => Promise<FilaVentas[]>> = {
    dia: consultarPorDia,
    producto: consultarPorProducto,
    medio: consultarPorMedio,
    usuario: consultarPorUsuario,
  };
  return consultas[agrupar](filtro);
}

export const ENCABEZADOS_EXPORTACION = [
  'fecha',
  'hora',
  'tipo',
  'serie',
  'correlativo',
  'cliente_tipo_documento',
  'cliente_numero_documento',
  'cliente_nombre',
  'moneda',
  'tipo_cambio',
  'forma_pago',
  'op_gravadas',
  'op_exoneradas',
  'op_inafectas',
  'igv',
  'icbper',
  'total',
  'importe_neto_pen',
  'estado',
  'usuario',
  'medios_pago',
] as const;

interface FilaExportacion {
  fecha: string;
  hora: string | null;
  tipo: string;
  serie: string;
  correlativo: number;
  cliente_tipo_documento: string | null;
  cliente_numero_documento: string | null;
  cliente_nombre: string | null;
  moneda: string;
  tipo_cambio: string | null;
  forma_pago: string | null;
  op_gravadas: string | null;
  op_exoneradas: string | null;
  op_inafectas: string | null;
  igv: string | null;
  icbper: string | null;
  total: string | null;
  importe_neto_pen: string | null;
  estado: string;
  usuario: string | null;
  medios_pago: string | null;
}

export async function consultarExportacion(filtro: FiltroReporte): Promise<CeldaCsv[][]> {
  const { rows } = await pool.query<FilaExportacion>(
    `SELECT to_char(c.fecha_emision, 'YYYY-MM-DD') AS fecha,
            to_char(c.hora_emision, 'HH24:MI:SS') AS hora,
            c.tipo::text AS tipo, c.serie, c.correlativo,
            c.cliente_tipo_documento, c.cliente_numero_documento, c.cliente_nombre,
            c.moneda, c.tipo_cambio::text AS tipo_cambio, c.forma_pago::text AS forma_pago,
            c.op_gravadas, c.op_exoneradas, c.op_inafectas, c.igv, c.icbper, c.total,
            (${SIGNO_SQL} * ROUND(c.total * ${FACTOR_CAMBIO_SQL}, 2))::text AS importe_neto_pen,
            c.estado::text AS estado,
            pe.nombre AS usuario,
            (SELECT string_agg(p.medio::text || ':' || p.monto::text, ' | ' ORDER BY p.medio)
               FROM pagos p WHERE p.comprobante_id = c.id) AS medios_pago
       FROM comprobantes c
       LEFT JOIN perfiles pe ON pe.id = c.usuario_id
      WHERE ${CONDICION_BASE}
      ORDER BY c.fecha_emision, c.hora_emision, c.tipo, c.serie, c.correlativo`,
    parametros(filtro),
  );
  const importe = (valor: string | null) => new Decimal(valor ?? 0);
  return rows.map((f) => [
    f.fecha,
    f.hora,
    f.tipo,
    f.serie,
    f.correlativo,
    f.cliente_tipo_documento,
    f.cliente_numero_documento,
    f.cliente_nombre,
    f.moneda,
    f.tipo_cambio,
    f.forma_pago,
    importe(f.op_gravadas),
    importe(f.op_exoneradas),
    importe(f.op_inafectas),
    importe(f.igv),
    importe(f.icbper),
    importe(f.total),
    importe(f.importe_neto_pen),
    f.estado,
    f.usuario,
    f.medios_pago,
  ]);
}
