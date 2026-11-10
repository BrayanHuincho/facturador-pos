import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { withTransaction } from '../../db/pool.js';
import { requerirRol } from '../../http/auth.js';
import { ErrorApi } from '../../http/errores.js';
import { ESCALA_CANTIDAD } from '../caja/calculos.js';
import { registrarAuditoria } from '../caja/repositorio.js';
import { cantidadConSigno, identificador, validar } from '../caja/validacion.js';
import { ajusteDejaStockInvalido, calcularNuevoStock } from './calculos.js';

const esquemaAjuste = z.object({
  producto_id: identificador,
  establecimiento_id: identificador,
  cantidad: cantidadConSigno,
  motivo: z.string().trim().min(1).max(500),
});

export async function stockRutas(app: FastifyInstance): Promise<void> {
  app.post('/stock/ajustes', { preHandler: requerirRol('admin') }, async (request, reply) => {
    const { producto_id, establecimiento_id, cantidad, motivo } = validar(esquemaAjuste, request.body);
    const usuarioId = request.usuario.id;

    const ajuste = await withTransaction(async (c) => {
      const producto = await c.query<{ controla_stock: boolean }>(
        'SELECT controla_stock FROM productos WHERE id = $1',
        [producto_id],
      );
      if (!producto.rows[0]) throw new ErrorApi(404, 'PRODUCTO_NO_ENCONTRADO', 'Producto no encontrado');
      if (!producto.rows[0].controla_stock) {
        throw new ErrorApi(409, 'PRODUCTO_SIN_CONTROL_STOCK', 'El producto no controla stock');
      }
      const establecimiento = await c.query('SELECT 1 FROM establecimientos WHERE id = $1', [establecimiento_id]);
      if (establecimiento.rowCount === 0) {
        throw new ErrorApi(404, 'ESTABLECIMIENTO_NO_ENCONTRADO', 'Establecimiento no encontrado');
      }

      await c.query(
        `INSERT INTO stock (producto_id, establecimiento_id, cantidad)
         VALUES ($1, $2, 0)
         ON CONFLICT (producto_id, establecimiento_id) DO NOTHING`,
        [producto_id, establecimiento_id],
      );
      const bloqueado = await c.query<{ id: string; cantidad: string }>(
        `SELECT id, cantidad FROM stock
          WHERE producto_id = $1 AND establecimiento_id = $2
          FOR UPDATE`,
        [producto_id, establecimiento_id],
      );
      const fila = bloqueado.rows[0]!;
      const nuevoStock = calcularNuevoStock(fila.cantidad, cantidad);
      if (ajusteDejaStockInvalido(cantidad, nuevoStock)) {
        throw new ErrorApi(409, 'STOCK_INSUFICIENTE', 'El ajuste dejaría el stock en negativo', {
          cantidad_actual: fila.cantidad,
        });
      }
      const cantidadActual = nuevoStock.toFixed(ESCALA_CANTIDAD);

      await c.query('UPDATE stock SET cantidad = $2, actualizado_en = now() WHERE id = $1', [fila.id, cantidadActual]);
      const movimiento = await c.query<{ id: string }>(
        `INSERT INTO movimientos_stock (producto_id, establecimiento_id, tipo, cantidad, usuario_id)
         VALUES ($1, $2, 'ajuste', $3, $4)
         RETURNING id`,
        [producto_id, establecimiento_id, cantidad, usuarioId],
      );
      const movimientoId = movimiento.rows[0]!.id;
      await registrarAuditoria(c, {
        usuarioId,
        accion: 'stock.ajuste',
        entidad: 'movimientos_stock',
        entidadId: movimientoId,
        detalle: {
          producto_id,
          establecimiento_id,
          cantidad_anterior: fila.cantidad,
          ajuste: cantidad,
          cantidad_actual: cantidadActual,
          motivo,
        },
      });
      return {
        movimiento_id: movimientoId,
        producto_id,
        establecimiento_id,
        cantidad_anterior: fila.cantidad,
        ajuste: cantidad,
        cantidad_actual: cantidadActual,
      };
    });
    return reply.status(201).send(ajuste);
  });
}
