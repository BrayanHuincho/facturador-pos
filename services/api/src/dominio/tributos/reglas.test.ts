import { describe, expect, it } from 'vitest';
import { decimal } from './dinero.js';
import {
  cadenaQr,
  claseDeAnulacion,
  detalleBaja,
  detalleResumen,
  ErrorRegla,
  estadoPorCodigo,
  leyendasDe,
  letraDeSerie,
  liquidarPagos,
  montoDetraccion,
  motivoDeNota,
  notaCopiaElAfectado,
  numeroOcupado,
  pendienteDeCredito,
  validarCliente,
  validarCuotas,
  validarDescuentos,
  validarDetraccion,
  validarFechaEmision,
  validarFechaNota,
  validarSaldoNota,
  validarTipoCambio,
  validarVencimiento,
} from './reglas.js';

const codigo = (fn: () => unknown): string | undefined => {
  try {
    fn();
  } catch (e) {
    return (e as ErrorRegla).codigo;
  }
  return undefined;
};

describe('leyendas y QR', () => {
  it('leyenda 1000 y adicionales', () => {
    expect(leyendasDe(decimal('495.60'), 'PEN')).toEqual([{ code: '1000', value: 'SON: CUATROCIENTOS NOVENTA Y CINCO CON 60/100 SOLES' }]);
    expect(leyendasDe(decimal(1000), 'PEN', { detraccion: true }).map((l) => l.code)).toEqual(['1000', '2006']);
    expect(leyendasDe(decimal(0), 'PEN', { gratuito: true }).map((l) => l.code)).toEqual(['1000', '1002']);
  });

  it('cadena del QR', () => {
    const qr = cadenaQr({
      ruc: '20503758114',
      tipo: '03',
      serie: 'B001',
      correlativo: 51,
      igv: '75.6',
      total: '495.6',
      fecha_emision: '2026-09-28',
      cliente_tipo_documento: '1',
      cliente_numero_documento: '44844391',
      hash: 'Tv8sZ8zmKaha5Q8qjK0TF4/b/0U=',
    });
    expect(qr).toBe('20503758114|03|B001|000051|75.60|495.60|2026-09-28|1|44844391|Tv8sZ8zmKaha5Q8qjK0TF4/b/0U=');
    expect(qr.split('|')).toHaveLength(10);
  });

  it('QR sin documento ni hash', () => {
    const qr = cadenaQr({ ruc: '20606883537', tipo: '03', serie: 'B001', correlativo: 7, igv: 18, total: 118, fecha_emision: '2026-09-01T10:00:00Z', cliente_tipo_documento: '0', cliente_numero_documento: null, hash: null });
    expect(qr.split('|').slice(6)).toEqual(['2026-09-01', '0', '0', '']);
  });
});

describe('cliente', () => {
  it('factura exige RUC', () => {
    expect(codigo(() => validarCliente('01', { tipo_documento: '1', numero_documento: '44844391' }, decimal(100), 'PEN'))).toBe('FACTURA_REQUIERE_RUC');
    expect(codigo(() => validarCliente('01', { tipo_documento: '0', numero_documento: null }, decimal(10), 'PEN'))).toBe('FACTURA_REQUIERE_RUC');
    expect(codigo(() => validarCliente('01', { tipo_documento: '6', numero_documento: '1234' }, decimal(10), 'PEN'))).toBe('FACTURA_REQUIERE_RUC');
    expect(codigo(() => validarCliente('01', { tipo_documento: '6', numero_documento: '20100055237' }, decimal(10), 'PEN'))).toBeUndefined();
  });

  it('boleta sin documento solo hasta 700', () => {
    const sin = { tipo_documento: '0' as const, numero_documento: '00000000' };
    expect(codigo(() => validarCliente('03', sin, decimal('700'), 'PEN'))).toBeUndefined();
    expect(codigo(() => validarCliente('03', sin, decimal('700.01'), 'PEN'))).toBe('BOLETA_REQUIERE_DOCUMENTO');
    expect(codigo(() => validarCliente('03', sin, decimal('700.01'), 'USD'))).toBeUndefined();
    expect(codigo(() => validarCliente('NV', sin, decimal('5000'), 'PEN'))).toBeUndefined();
    expect(codigo(() => validarCliente('03', { tipo_documento: '1', numero_documento: '44844391' }, decimal(5000), 'PEN'))).toBeUndefined();
  });

  it('formatos de documento', () => {
    expect(codigo(() => validarCliente('03', { tipo_documento: '1', numero_documento: '4484439' }, decimal(10), 'PEN'))).toBe('DOCUMENTO_INVALIDO');
    expect(codigo(() => validarCliente('03', { tipo_documento: '6', numero_documento: '30100055237' }, decimal(10), 'PEN'))).toBe('DOCUMENTO_INVALIDO');
    expect(codigo(() => validarCliente('03', { tipo_documento: '7', numero_documento: 'ab' }, decimal(10), 'PEN'))).toBe('DOCUMENTO_INVALIDO');
  });

  it('tipo de cambio obligatorio en dólares', () => {
    expect(codigo(() => validarTipoCambio('USD', undefined))).toBe('TIPO_CAMBIO_REQUERIDO');
    expect(codigo(() => validarTipoCambio('USD', '3.75'))).toBeUndefined();
    expect(codigo(() => validarTipoCambio('PEN', undefined))).toBeUndefined();
  });
});

describe('fechas', () => {
  it('emisión ni futura ni fuera de plazo', () => {
    expect(codigo(() => validarFechaEmision('2026-09-29', '2026-09-28', '03'))).toBe('FECHA_FUTURA');
    expect(codigo(() => validarFechaEmision('2026-09-24', '2026-09-28', '01'))).toBe('FECHA_FUERA_DE_PLAZO');
    expect(codigo(() => validarFechaEmision('2026-09-25', '2026-09-28', '01'))).toBeUndefined();
    expect(codigo(() => validarFechaEmision('2026-09-21', '2026-09-28', '03'))).toBeUndefined();
    expect(codigo(() => validarFechaEmision('2026-09-20', '2026-09-28', '03'))).toBe('FECHA_FUERA_DE_PLAZO');
  });

  it('nota no anterior al afectado', () => {
    expect(codigo(() => validarFechaNota('2026-09-20', '2026-09-21'))).toBe('FECHA_ANTERIOR_AL_AFECTADO');
    expect(codigo(() => validarFechaNota('2026-09-21', '2026-09-21'))).toBeUndefined();
  });

  it('vencimiento', () => {
    expect(codigo(() => validarVencimiento('2026-09-27', '2026-09-28'))).toBe('VENCIMIENTO_ANTES_DE_EMISION');
    expect(codigo(() => validarVencimiento('2026-10-01', '2026-09-28', '2026-10-28'))).toBe('VENCIMIENTO_ANTES_DE_CUOTA');
    expect(codigo(() => validarVencimiento(null, '2026-09-28'))).toBeUndefined();
    expect(codigo(() => validarVencimiento('2026-10-28', '2026-09-28', '2026-10-28'))).toBeUndefined();
  });
});

describe('crédito y detracción', () => {
  it('cuotas', () => {
    expect(codigo(() => validarCuotas([], decimal(100), '2026-09-28'))).toBe('CUOTAS_REQUERIDAS');
    expect(codigo(() => validarCuotas([{ monto: 50, fecha_pago: '2026-10-28' }], decimal(100), '2026-09-28'))).toBe('CUOTAS_NO_CUADRAN');
    expect(codigo(() => validarCuotas([{ monto: 100, fecha_pago: '2026-09-28' }], decimal(100), '2026-09-28'))).toBe('CUOTA_FECHA_INVALIDA');
    expect(
      validarCuotas(
        [
          { monto: 60, fecha_pago: '2026-11-28' },
          { monto: 40, fecha_pago: '2026-10-28' },
        ],
        decimal(100),
        '2026-09-28',
      ),
    ).toEqual([
      { monto: '40.00', fecha_pago: '2026-10-28' },
      { monto: '60.00', fecha_pago: '2026-11-28' },
    ]);
  });

  it('pendiente de crédito', () => {
    expect(pendienteDeCredito(decimal('1180.00')).toFixed(2)).toBe('1180.00');
    expect(pendienteDeCredito(decimal('1180.00'), '500.00').toFixed(2)).toBe('680.00');
    expect(codigo(() => pendienteDeCredito(decimal('1180.00'), '1180.00'))).toBe('YA_PAGADO');
  });

  it('detracción sin decimales', () => {
    expect(montoDetraccion(decimal('1180'), 12).toFixed(2)).toBe('142.00');
    expect(validarDetraccion('01', 'PEN', decimal('1180'), 12).toFixed(2)).toBe('142.00');
    expect(codigo(() => validarDetraccion('03', 'PEN', decimal('1180'), 12))).toBe('DETRACCION_SOLO_FACTURA');
    expect(codigo(() => validarDetraccion('01', 'USD', decimal('1180'), 12))).toBe('DETRACCION_SOLO_SOLES');
    expect(codigo(() => validarDetraccion('01', 'PEN', decimal('700'), 12))).toBe('DETRACCION_MINIMO');
  });

  it('descuento no supera el importe', () => {
    expect(codigo(() => validarDescuentos([{ cantidad: 2, precio: 10, descuento: '20.01' }]))).toBe('DESCUENTO_EXCEDE_IMPORTE');
    expect(codigo(() => validarDescuentos([{ cantidad: 2, precio: 10, descuento: 20 }]))).toBeUndefined();
  });
});

describe('pagos', () => {
  it('registra el neto en efectivo y calcula el vuelto', () => {
    const r = liquidarPagos([{ medio: 'efectivo', monto: 50 }], decimal('38.00'), 'contado');
    expect(r.recibido.toFixed(2)).toBe('50.00');
    expect(r.vuelto.toFixed(2)).toBe('12.00');
    expect(r.pagos.map((p) => p.monto.toFixed(2))).toEqual(['38.00']);
  });

  it('pago mixto descuenta el vuelto solo del efectivo', () => {
    const r = liquidarPagos(
      [
        { medio: 'yape', monto: 20 },
        { medio: 'efectivo', monto: 30 },
      ],
      decimal('38.00'),
      'contado',
    );
    expect(r.vuelto.toFixed(2)).toBe('12.00');
    expect(r.pagos.map((p) => [p.medio, p.monto.toFixed(2)])).toEqual([
      ['yape', '20.00'],
      ['efectivo', '18.00'],
    ]);
  });

  it('la suma de los pagos netos iguala el total', () => {
    const r = liquidarPagos([{ medio: 'efectivo', monto: 5 }, { medio: 'efectivo', monto: 40 }, { medio: 'tarjeta', monto: 10 }], decimal('38.50'), 'contado');
    expect(r.pagos.reduce((s, p) => s.add(p.monto), decimal(0)).toFixed(2)).toBe('38.50');
    expect(r.recibido.toFixed(2)).toBe('55.00');
    expect(r.vuelto.toFixed(2)).toBe('16.50');
  });

  it('rechaza pago corto y vuelto sobre medios electrónicos', () => {
    expect(codigo(() => liquidarPagos([{ medio: 'efectivo', monto: 10 }], decimal(38), 'contado'))).toBe('PAGO_INSUFICIENTE');
    expect(codigo(() => liquidarPagos([{ medio: 'yape', monto: 50 }], decimal(38), 'contado'))).toBe('PAGO_EXCEDE_TOTAL');
    expect(codigo(() => liquidarPagos([{ medio: 'yape', monto: 40 }, { medio: 'efectivo', monto: 1 }], decimal(38), 'contado'))).toBe('PAGO_EXCEDE_TOTAL');
  });

  it('crédito admite adelanto pero no pago total', () => {
    expect(liquidarPagos([{ medio: 'yape', monto: 10 }], decimal(38), 'credito').pagado.toFixed(2)).toBe('10.00');
    expect(codigo(() => liquidarPagos([{ medio: 'yape', monto: 38 }], decimal(38), 'credito'))).toBe('YA_PAGADO');
  });
});

describe('notas', () => {
  it('motivos', () => {
    expect(motivoDeNota('07', '01').etiqueta).toBe('Anulación de la operación');
    expect(motivoDeNota('08', '02').etiqueta).toBe('Aumento en el valor');
    expect(codigo(() => motivoDeNota('07', '13'))).toBe('MOTIVO_INVALIDO');
    expect(codigo(() => motivoDeNota('08', '04'))).toBe('MOTIVO_INVALIDO');
  });

  it('copia el afectado sin ítems o cuando el motivo anula', () => {
    expect(notaCopiaElAfectado('07', '09', false)).toBe(true);
    expect(notaCopiaElAfectado('07', '01', true)).toBe(true);
    expect(notaCopiaElAfectado('07', '06', true)).toBe(true);
    expect(notaCopiaElAfectado('07', '09', true)).toBe(false);
    expect(notaCopiaElAfectado('08', '01', true)).toBe(false);
  });

  it('saldo por acreditar', () => {
    expect(codigo(() => validarSaldoNota(decimal('60.01'), '100', '40'))).toBe('NOTA_EXCEDE_SALDO');
    expect(codigo(() => validarSaldoNota(decimal('60'), '100', '40'))).toBeUndefined();
  });

  it('letra de serie', () => {
    expect(letraDeSerie('01')).toBe('F');
    expect(letraDeSerie('03')).toBe('B');
  });
});

describe('estados SUNAT', () => {
  it('traduce códigos', () => {
    expect(estadoPorCodigo('0', true)).toBe('aceptado');
    expect(estadoPorCodigo(null, true)).toBe('aceptado');
    expect(estadoPorCodigo('4252', true)).toBe('observado');
    expect(estadoPorCodigo('2017', false)).toBe('rechazado');
    expect(estadoPorCodigo('0102', false)).toBe('error');
    expect(estadoPorCodigo('abc', false)).toBe('error');
  });

  it('número ocupado', () => {
    expect(numeroOcupado({ estado: 'error', sunat_codigo: '1033' })).toBe(true);
    expect(numeroOcupado({ estado: 'error', sunat_codigo: '0102' })).toBe(false);
    expect(numeroOcupado({ estado: 'aceptado', sunat_codigo: null })).toBe(false);
  });
});

describe('anulación', () => {
  const base = { tipo: '01', estado: 'aceptado', fecha_emision: '2026-09-25', afectado_tipo: null };

  it('factura y sus notas por baja, boleta y sus notas por resumen', () => {
    expect(claseDeAnulacion(base, '2026-09-28')).toBe('baja');
    expect(claseDeAnulacion({ ...base, tipo: '07', afectado_tipo: '01' }, '2026-09-28')).toBe('baja');
    expect(claseDeAnulacion({ ...base, tipo: '03' }, '2026-09-28')).toBe('resumen');
    expect(claseDeAnulacion({ ...base, tipo: '07', afectado_tipo: '03' }, '2026-09-28')).toBe('resumen');
  });

  it('el plazo es de 7 días', () => {
    expect(claseDeAnulacion(base, '2026-10-02')).toBe('baja');
    expect(codigo(() => claseDeAnulacion(base, '2026-10-03'))).toBe('PLAZO_DE_BAJA_VENCIDO');
  });

  it('nota de venta y rechazados se anulan localmente sin plazo', () => {
    expect(claseDeAnulacion({ ...base, tipo: 'NV', estado: 'no_aplica' }, '2027-01-01')).toBe('local');
    expect(claseDeAnulacion({ ...base, estado: 'rechazado' }, '2027-01-01')).toBe('local');
    expect(claseDeAnulacion({ ...base, estado: 'error', sunat_codigo: '1033' }, '2027-01-01')).toBe('local');
  });

  it('estados que no se anulan', () => {
    expect(codigo(() => claseDeAnulacion({ ...base, estado: 'anulado' }, '2026-09-28'))).toBe('YA_ANULADO');
    expect(codigo(() => claseDeAnulacion({ ...base, estado: 'por_anular' }, '2026-09-28'))).toBe('ANULACION_EN_TRAMITE');
    expect(codigo(() => claseDeAnulacion({ ...base, estado: 'pendiente' }, '2026-09-28'))).toBe('NO_SE_PUEDE_ANULAR');
    expect(codigo(() => claseDeAnulacion({ ...base, estado: 'por_resumen' }, '2026-09-28'))).toBe('NO_SE_PUEDE_ANULAR');
  });

  it('detalles de resumen y baja', () => {
    const detalle = detalleResumen(
      { tipo: '07', serie: 'B001', correlativo: 5, cliente_tipo_documento: '1', cliente_numero_documento: '44844391', total: '118.00', op_gravadas: '100.00', op_exoneradas: 0, op_inafectas: 0, op_gratuitas: 0, igv: '18.00', icbper: 0, afectado_tipo: '03', afectado_serie: 'B001', afectado_correlativo: 12 },
      '3',
    );
    expect(detalle.serie_numero).toBe('B001-000005');
    expect(detalle.estado).toBe('3');
    expect(detalle.documento_referencia).toEqual({ tipo_documento: '03', numero_documento: 'B001-000012' });
    expect(detalleBaja({ tipo: '01', serie: 'F001', correlativo: 9 }, 'Error')).toEqual({ tipo_documento: '01', serie: 'F001', correlativo: '000009', motivo_especifico: 'Error' });
  });
});
