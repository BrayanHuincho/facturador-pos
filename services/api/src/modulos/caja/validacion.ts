import { z } from 'zod';
import { ErrorApi } from '../../http/errores.js';

export function validar<T extends z.ZodType>(esquema: T, datos: unknown): z.output<T> {
  const resultado = esquema.safeParse(datos);
  if (!resultado.success) {
    throw new ErrorApi(400, 'DATOS_INVALIDOS', 'Los datos enviados no son válidos', z.flattenError(resultado.error));
  }
  return resultado.data;
}

const textoNumerico = z.union([z.string().trim(), z.number()]).transform(String);

export const importeNoNegativo = textoNumerico.refine((valor) => /^\d{1,16}(\.\d{1,2})?$/.test(valor), {
  message: 'Debe ser un importe de hasta 2 decimales',
});

export const importePositivo = importeNoNegativo.refine((valor) => /[1-9]/.test(valor), {
  message: 'Debe ser mayor que cero',
});

export const cantidadConSigno = textoNumerico
  .refine((valor) => /^[+-]?\d{1,14}(\.\d{1,4})?$/.test(valor), {
    message: 'Debe ser una cantidad de hasta 4 decimales',
  })
  .refine((valor) => /[1-9]/.test(valor), { message: 'No puede ser cero' });

export const identificador = z.guid();
