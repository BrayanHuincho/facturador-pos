import { describe, expect, it } from 'vitest';
import { formatoValido, miles, peticionComprobante, peticionGuia, peticionVistaPrevia, type ComprobantePdf, type EmpresaPdf, type GuiaPdf } from './peticion.js';

const empresa: EmpresaPdf = { ruc: '20123456789', razon_social: 'ACME SAC', nombre_comercial: null, direccion: 'Av 1', distrito: 'LIMA', provincia: 'LIMA', departamento: 'LIMA', telefono: null, correo: null, plantilla_pdf: 'moderna' };

const comprobante = (parcial: Partial<ComprobantePdf> = {}): ComprobantePdf => ({
  tipo: '03',
  serie: 'B001',
  correlativo: 12,
  fecha_emision: '2026-11-09',
  hora_emision: '10:00:00',
  moneda: 'PEN',
  tipo_cambio: null,
  forma_pago: 'contado',
  cuotas: null,
  cliente_tipo_documento: '1',
  cliente_numero_documento: '44444444',
  cliente_nombre: 'JUAN',
  cliente_direccion: null,
  op_gravadas: '1000.00',
  op_exoneradas: '0.00',
  op_inafectas: '0.00',
  op_gratuitas: '0.00',
  descuento_total: '0.00',
  igv: '180.00',
  icbper: '0.00',
  total: '1180.00',
  detraccion: null,
  leyendas: [{ codigo: '1000', valor: 'SON MIL' }],
  afectado_tipo: null,
  afectado_serie: null,
  afectado_correlativo: null,
  motivo_codigo: null,
  motivo_descripcion: null,
  estado: 'aceptado',
  hash: 'H',
  qr: 'QR',
  entorno: 'produccion',
  establecimiento_direccion: null,
  usuario_nombre: 'Ana',
  igv_porcentaje: '18',
  items: [{ codigo: 'P1', descripcion: 'Item', unidad: 'niu', cantidad: '1.0000', precio_unitario: '1180.000000', valor_unitario: '1000.000000', descuento: '0.00', afectacion: '10', total: '1180.00' }],
  ...parcial,
});

describe('petición del PDF', () => {
  it('manda la plantilla de la empresa y mapea el formato', () => {
    const p = peticionComprobante(comprobante(), empresa, 'ticket58', null);
    expect(p).toMatchObject({ plantilla: 'moderna', formato: '50mm', qr_texto: 'QR' });
    expect(p.datos).toMatchObject({ total: '1,180.00', letras: 'SON MIL', hash: 'H' });
  });

  it('sin plantilla usa clasica', () => {
    expect(peticionComprobante(comprobante(), { ...empresa, plantilla_pdf: null }, 'a4', null).plantilla).toBe('clasica');
  });

  it('la nota de venta no lleva QR ni hash', () => {
    const p = peticionComprobante(comprobante({ tipo: 'NV' }), empresa, 'ticket80', null);
    expect(p).toMatchObject({ formato: '80mm', qr_texto: null });
    expect(p.datos.hash).toBeNull();
  });

  it('sella anulado y beta', () => {
    expect(peticionComprobante(comprobante({ estado: 'anulado' }), empresa, 'a4', null).datos.sello).toBe('ANULADO');
    expect(peticionComprobante(comprobante({ entorno: 'beta' }), empresa, 'a4', null).datos.sello).toBe('PRUEBA');
  });

  it('la vista previa no lleva número, QR ni hash y va sellada', () => {
    const p = peticionVistaPrevia(comprobante({ hash: 'H', qr: 'QR', entorno: 'produccion' }), empresa, 'ticket80', null);
    expect(p).toMatchObject({ plantilla: 'moderna', formato: '80mm', qr_texto: null });
    expect(p.datos).toMatchObject({ documento: { numero: 'POR EMITIR' }, hash: null, vista_previa: true, sello: 'VISTA PREVIA', representacion: 'Vista previa, sin validez', total: '1,180.00' });
  });

  it('acepta los formatos de la ruta de archivos', () => {
    expect(formatoValido('pdf-ticket80')).toBe('ticket80');
    expect(() => formatoValido('a5')).toThrow();
    expect(miles('1234567.5')).toBe('1,234,567.50');
  });

  it('guía con la plantilla de la empresa', () => {
    const g = { serie: 'T001', correlativo: 1, fecha_emision: '2026-11-09', fecha_traslado: '2026-11-10', motivo_codigo: '01', modalidad: '01', peso_total: '10.5000', unidad_peso: 'KGM', bultos: null, partida_ubigeo: '150101', partida_direccion: 'A', llegada_ubigeo: '150102', llegada_direccion: 'B', destinatario_tipo_documento: '6', destinatario_numero_documento: '20100055237', destinatario_nombre: 'X', transportista: { ruc: '20999999999', razon_social: 'T' }, conductor: null, vehiculo_placa: null, relacionado: null, estado: 'aceptado', hash: null, qr: 'http://q', entorno: 'produccion', establecimiento_direccion: null, items: [] } as GuiaPdf;
    expect(peticionGuia(g, empresa, 'a4', null)).toMatchObject({ plantilla: 'moderna', formato: 'A4', qr_texto: 'http://q' });
  });

  it('prioriza ANULADO sobre PRUEBA, también mientras la baja está en curso', () => {
    expect(peticionComprobante(comprobante({ entorno: 'beta', estado: 'anulado' }), empresa, 'a4', null).datos.sello).toBe('ANULADO');
    expect(peticionComprobante(comprobante({ entorno: 'beta', estado: 'por_anular' }), empresa, 'ticket80', null).datos.sello).toBe('ANULADO');
    expect(peticionComprobante(comprobante({ entorno: 'beta' }), empresa, 'ticket58', null).datos.sello).toBe('PRUEBA');
    expect(peticionVistaPrevia(comprobante({ entorno: 'beta' }), empresa, 'a4', null).datos.sello).toBe('VISTA PREVIA');
  });
});
