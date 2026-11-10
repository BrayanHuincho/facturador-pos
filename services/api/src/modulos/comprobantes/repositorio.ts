import type { PoolClient } from 'pg';
import { ErrorApi } from '../../http/errores.js';
import { decimal, type Decimal } from '../../dominio/tributos/index.js';
import type { TipoDocumentoIdentidad } from '../../dominio/tributos/index.js';

export interface ComprobanteFila {
  id: string;
  establecimiento_id: string;
  usuario_id: string;
  tipo: string;
  serie: string;
  correlativo: number;
  fecha_emision: string;
  moneda: 'PEN' | 'USD';
  tipo_cambio: string | null;
  cliente_id: string | null;
  cliente_tipo_documento: TipoDocumentoIdentidad;
  cliente_numero_documento: string | null;
  cliente_nombre: string;
  cliente_direccion: string | null;
  op_gravadas: string;
  op_exoneradas: string;
  op_inafectas: string;
  op_gratuitas: string;
  igv: string;
  icbper: string;
  total: string;
  afectado_tipo: string | null;
  afectado_serie: string | null;
  afectado_correlativo: number | null;
  estado: string;
  sunat_codigo: string | null;
  hash: string | null;
  xml_path: string | null;
  cdr_path: string | null;
  entorno: string;
  resumen_id: string | null;
}

export interface ItemFila {
  producto_id: string | null;
  codigo: string | null;
  descripcion: string;
  unidad: string;
  cantidad: string;
  valor_unitario: string;
  precio_unitario: string;
  descuento: string;
  afectacion: string;
  base: string;
  igv: string;
  icbper: string;
  total: string;
}

export interface EmpresaContexto {
  ruc: string;
  razon_social: string;
  nombre_comercial: string | null;
  ubigeo: string | null;
  departamento: string | null;
  provincia: string | null;
  distrito: string | null;
  direccion: string | null;
  igv_porcentaje: string;
  precios_incluyen_igv: boolean;
  configurada: boolean;
  entorno: string;
  envio_boletas: string;
}

export interface LineaStock {
  producto_id: string;
  cantidad: Decimal;
}

const COLUMNAS_COMPROBANTE = `c.*, c.fecha_emision::text AS fecha_emision, c.hora_emision::text AS hora_emision`;

export const hoyEnLima = (): string => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Lima', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());

export const horaEnLima = (): string =>
  new Intl.DateTimeFormat('en-GB', { timeZone: 'America/Lima', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' }).format(new Date());

export async function cargarEmpresa(c: PoolClient): Promise<EmpresaContexto> {
  const { rows } = await c.query<EmpresaContexto>(
    `SELECT e.ruc, e.razon_social, e.nombre_comercial, e.ubigeo, e.departamento, e.provincia, e.distrito, e.direccion,
            e.igv_porcentaje, e.precios_incluyen_igv, e.configurada,
            COALESCE(s.entorno, 'beta') AS entorno, COALESCE(s.envio_boletas, 'individual') AS envio_boletas
       FROM empresa e LEFT JOIN configuracion_sunat s ON s.id = 1
      WHERE e.id = 1`,
  );
  const empresa = rows[0];
  if (!empresa?.configurada) throw new ErrorApi(409, 'EMPRESA_NO_CONFIGURADA', 'Completa la configuración inicial de la empresa antes de emitir.');
  return empresa;
}

export async function buscarSerie(
  c: PoolClient,
  filtro: { tipo: string; serie?: string; establecimientoObligatorio: string | null; establecimientoPreferido: string | null; letra?: string },
): Promise<{ id: string; serie: string; establecimiento_id: string }> {
  const { rows } = await c.query<{ id: string; serie: string; establecimiento_id: string }>(
    `SELECT id, serie, establecimiento_id
       FROM series
      WHERE tipo = $1 AND activa
        AND ($2::text IS NULL OR serie = $2)
        AND ($3::uuid IS NULL OR establecimiento_id = $3)
        AND ($4::text IS NULL OR serie LIKE $4 || '%')
      ORDER BY (establecimiento_id = $5::uuid) DESC NULLS LAST, serie
      LIMIT 1`,
    [filtro.tipo, filtro.serie ?? null, filtro.establecimientoObligatorio, filtro.letra ?? null, filtro.establecimientoPreferido],
  );
  const serie = rows[0];
  if (!serie) throw new ErrorApi(422, 'SERIE_NO_EXISTE', 'No hay una serie activa disponible para este comprobante.');
  return serie;
}

export async function reservarCorrelativo(c: PoolClient, serieId: string): Promise<number> {
  const { rows } = await c.query<{ ultimo: number }>('UPDATE series SET ultimo = ultimo + 1, actualizado_en = now() WHERE id = $1 AND activa RETURNING ultimo', [serieId]);
  const fila = rows[0];
  if (!fila) throw new ErrorApi(409, 'SERIE_NO_DISPONIBLE', 'La serie ya no está activa.');
  return fila.ultimo;
}

export async function turnoAbierto(c: PoolClient, usuarioId: string): Promise<string | null> {
  const { rows } = await c.query<{ id: string }>(`SELECT id FROM turnos_caja WHERE usuario_id = $1 AND estado = 'abierto' FOR SHARE`, [usuarioId]);
  return rows[0]?.id ?? null;
}

export async function insertarFila(c: PoolClient, tabla: 'comprobantes' | 'comprobante_items' | 'pagos' | 'resumenes_diarios' | 'comunicaciones_baja', datos: Record<string, unknown>): Promise<string> {
  const columnas = Object.keys(datos);
  const marcadores = columnas.map((_, indice) => `$${indice + 1}`);
  const { rows } = await c.query<{ id: string }>(`INSERT INTO ${tabla} (${columnas.join(', ')}) VALUES (${marcadores.join(', ')}) RETURNING id`, Object.values(datos));
  return rows[0]!.id;
}

export function agruparStock(lineas: { producto_id: string | null; controla_stock: boolean; cantidad: Decimal }[]): LineaStock[] {
  const porProducto = new Map<string, Decimal>();
  for (const linea of lineas) {
    if (!linea.producto_id || !linea.controla_stock) continue;
    porProducto.set(linea.producto_id, (porProducto.get(linea.producto_id) ?? decimal(0)).add(linea.cantidad));
  }
  return [...porProducto.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([producto_id, cantidad]) => ({ producto_id, cantidad }));
}

export async function moverStock(
  c: PoolClient,
  lineas: LineaStock[],
  movimiento: { tipo: 'venta' | 'anulacion'; signo: 1 | -1; establecimientoId: string; comprobanteId: string; usuarioId: string },
): Promise<void> {
  for (const linea of lineas) {
    const delta = linea.cantidad.mul(movimiento.signo).toFixed(4);
    await c.query(
      `INSERT INTO stock (producto_id, establecimiento_id, cantidad) VALUES ($1, $2, $3::numeric)
       ON CONFLICT (producto_id, establecimiento_id) DO UPDATE SET cantidad = stock.cantidad + EXCLUDED.cantidad, actualizado_en = now()`,
      [linea.producto_id, movimiento.establecimientoId, delta],
    );
    await c.query(
      `INSERT INTO movimientos_stock (producto_id, establecimiento_id, tipo, cantidad, referencia_id, usuario_id) VALUES ($1, $2, $3, $4::numeric, $5, $6)`,
      [linea.producto_id, movimiento.establecimientoId, movimiento.tipo, delta, movimiento.comprobanteId, movimiento.usuarioId],
    );
  }
}

export async function bloquearComprobante(c: PoolClient, id: string): Promise<ComprobanteFila | null> {
  const { rows } = await c.query<ComprobanteFila>(`SELECT ${COLUMNAS_COMPROBANTE} FROM comprobantes c WHERE c.id = $1 FOR UPDATE`, [id]);
  return rows[0] ?? null;
}

export async function itemsDe(c: PoolClient, id: string): Promise<ItemFila[]> {
  const { rows } = await c.query<ItemFila>('SELECT * FROM comprobante_items WHERE comprobante_id = $1 ORDER BY orden', [id]);
  return rows;
}

export async function comprobanteCompleto(c: PoolClient, id: string): Promise<(ComprobanteFila & { items: unknown[]; pagos: unknown[] }) | null> {
  const { rows } = await c.query<ComprobanteFila>(`SELECT ${COLUMNAS_COMPROBANTE} FROM comprobantes c WHERE c.id = $1`, [id]);
  const comprobante = rows[0];
  if (!comprobante) return null;
  const items = await itemsDe(c, id);
  const pagos = await c.query('SELECT id, medio, monto, referencia FROM pagos WHERE comprobante_id = $1 ORDER BY creado_en, id', [id]);
  return { ...comprobante, items, pagos: pagos.rows };
}
