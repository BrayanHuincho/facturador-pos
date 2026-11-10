import { beforeEach, describe, expect, it, vi } from 'vitest';

const consultas: string[] = [];
const respuestaDe = (sql: string): { rows: unknown[] } => {
  if (sql.includes('FROM empresa e')) {
    return { rows: [{ ruc: '20123456789', razon_social: 'ACME', igv_porcentaje: '18', precios_incluyen_igv: true, configurada: true, entorno: 'beta', envio_boletas: 'individual' }] };
  }
  if (sql.includes('FROM series')) return { rows: [{ id: 's1', serie: 'B001', establecimiento_id: 'e1' }] };
  if (sql.includes('FROM establecimientos')) return { rows: [{ direccion: 'AV LOCAL 1' }] };
  if (sql.includes('FROM perfiles')) return { rows: [{ nombre: 'Ana' }] };
  return { rows: [] };
};
const cliente = {
  query: vi.fn(async (sql: string) => {
    consultas.push(sql);
    return respuestaDe(sql);
  }),
};

vi.mock('../../db/pool.js', () => ({ withTransaction: (fn: (c: unknown) => unknown) => fn(cliente), pool: { query: vi.fn() } }));
vi.mock('../../db/auditoria.js', () => ({ registrarAuditoria: vi.fn() }));
vi.mock('../../cola/encolar.js', () => ({ encolar: vi.fn() }));
vi.mock('../../sunat/cliente.js', () => {
  class ErrorRedSunat extends Error {}
  class ErrorDatosSunat extends Error {}
  return { ErrorRedSunat, ErrorDatosSunat };
});
vi.mock('../../pdf/generar.js', () => ({ generarPdfVistaPrevia: vi.fn() }));

import { generarPdfVistaPrevia } from '../../pdf/generar.js';
import { ErrorRedSunat } from '../../sunat/cliente.js';
import { vistaPreviaPdf } from './emision.js';
import { esquemaVenta, esquemaVistaPrevia } from './esquemas.js';

const usuario = { id: '11111111-1111-1111-1111-111111111111', rol: 'admin', establecimiento_id: null } as never;
const venta = (parcial: Record<string, unknown> = {}) =>
  esquemaVenta.parse({
    tipo: '03',
    cliente: { tipo_documento: '1', numero_documento: '44444444', nombre: 'JUAN' },
    items: [{ descripcion: 'Item', cantidad: '2', precio_unitario: '10' }],
    pagos: [{ medio: 'efectivo', monto: '20' }],
    ...parcial,
  });

describe('vista previa del comprobante', () => {
  beforeEach(() => {
    consultas.length = 0;
    vi.mocked(generarPdfVistaPrevia).mockReset();
    vi.mocked(generarPdfVistaPrevia).mockResolvedValue(Buffer.from('%PDF-1'));
  });

  it('calcula y pide el PDF sin escribir ni consumir correlativo', async () => {
    const pdf = await vistaPreviaPdf(usuario, venta(), 'ticket58');
    expect(pdf.toString()).toBe('%PDF-1');
    expect(consultas.every((sql) => !/^\s*(INSERT|UPDATE|DELETE)/i.test(sql))).toBe(true);
    const [borrador, formato] = vi.mocked(generarPdfVistaPrevia).mock.calls[0]!;
    expect(formato).toBe('ticket58');
    expect(borrador).toMatchObject({ tipo: '03', correlativo: 0, total: '20.00', hash: null, qr: null, establecimiento_direccion: 'AV LOCAL 1', usuario_nombre: 'Ana' });
    expect(borrador.items[0]).toMatchObject({ descripcion: 'Item', total: '20.00' });
  });

  it('aplica las reglas del comprobante antes de generar', async () => {
    await expect(vistaPreviaPdf(usuario, venta({ tipo: '01' }), 'a4')).rejects.toBeInstanceOf(Error);
    expect(generarPdfVistaPrevia).not.toHaveBeenCalled();
  });

  it('un gateway caído es un error reintentable', async () => {
    vi.mocked(generarPdfVistaPrevia).mockRejectedValue(new ErrorRedSunat('caido'));
    await expect(vistaPreviaPdf(usuario, venta(), 'a4')).rejects.toMatchObject({ status: 503, codigo: 'PDF_NO_DISPONIBLE' });
  });

  it('el formato por defecto es ticket de 80 mm', () => {
    expect(esquemaVistaPrevia.parse({}).formato).toBe('ticket80');
    expect(() => esquemaVistaPrevia.parse({ formato: 'a5' })).toThrow();
  });
});
