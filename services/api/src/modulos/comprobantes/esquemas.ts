import { z } from 'zod';

const numeroConEscala = (decimales: number) =>
  z
    .union([z.string().trim().regex(/^\d+(\.\d+)?$/), z.number().finite().nonnegative()])
    .transform(String)
    .refine((valor) => new RegExp(`^\\d+(\\.\\d{1,${decimales}})?$`).test(valor), `Admite hasta ${decimales} decimales.`);

const importe = numeroConEscala(2);
const cantidad = numeroConEscala(4).refine((valor) => Number(valor) > 0, 'Debe ser mayor a cero.');
const precio = numeroConEscala(6);
const fecha = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const afectacion = z.enum(['10', '20', '30']);
const tipoDocumento = z.enum(['0', '1', '4', '6', '7']);

const item = z.object({
  producto_id: z.uuid().optional(),
  codigo: z.string().trim().max(60).optional(),
  descripcion: z.string().trim().min(1).max(500).optional(),
  unidad: z.string().trim().min(1).max(10).optional(),
  cantidad,
  precio_unitario: precio.optional(),
  descuento: importe.optional(),
  afectacion: afectacion.optional(),
});

const pago = z.object({
  medio: z.enum(['efectivo', 'yape', 'plin', 'transferencia', 'tarjeta', 'deposito', 'otro']),
  monto: importe,
  referencia: z.string().trim().max(100).optional(),
});

export const esquemaVenta = z.object({
  tipo: z.enum(['01', '03', 'NV']),
  serie: z.string().trim().length(4).toUpperCase().optional(),
  cliente: z
    .object({
      tipo_documento: tipoDocumento,
      numero_documento: z.string().trim().max(20).optional().default(''),
      nombre: z.string().trim().max(300).optional().default(''),
      direccion: z.string().trim().max(300).optional(),
    })
    .optional(),
  cliente_id: z.uuid().optional(),
  items: z.array(item).min(1).max(300),
  pagos: z.array(pago).max(20).default([]),
  forma_pago: z.enum(['contado', 'credito']).default('contado'),
  cuotas: z.array(z.object({ monto: importe, fecha_pago: fecha })).max(60).optional(),
  detraccion: z
    .object({
      codigo_bien_servicio: z.string().regex(/^\d{3}$/),
      porcentaje: numeroConEscala(2).refine((valor) => Number(valor) > 0 && Number(valor) <= 100, 'Porcentaje fuera de rango.'),
      cuenta_banco: z.string().trim().max(40).optional(),
      codigo_medio_pago: z.string().regex(/^\d{3}$/).optional(),
    })
    .optional(),
  moneda: z.enum(['PEN', 'USD']).default('PEN'),
  tipo_cambio: numeroConEscala(6).optional(),
  observacion: z.string().trim().max(1000).optional(),
  fecha_emision: fecha.optional(),
});

export const esquemaNota = z.object({
  tipo: z.enum(['07', '08']),
  afectado_id: z.uuid(),
  motivo_codigo: z.string().regex(/^\d{2}$/),
  motivo_descripcion: z.string().trim().max(250).optional(),
  serie: z.string().trim().length(4).toUpperCase().optional(),
  items: z.array(item).max(300).optional(),
  fecha_emision: fecha.optional(),
});

export const esquemaAnular = z.object({ motivo: z.string().trim().min(3).max(100) });
export const esquemaId = z.object({ id: z.uuid() });
export const esquemaArchivo = z.object({ id: z.uuid(), tipo: z.enum(['pdf-a4', 'pdf-ticket80', 'pdf-ticket58', 'xml', 'cdr']) });
export const esquemaVistaPrevia = z.object({ formato: z.enum(['a4', 'ticket80', 'ticket58']).default('ticket80') });
export const esquemaClaveIdempotencia = z.string().trim().min(8).max(200);

export type CuerpoVenta = z.infer<typeof esquemaVenta>;
export type CuerpoNota = z.infer<typeof esquemaNota>;
export type ItemCuerpo = z.infer<typeof item>;
