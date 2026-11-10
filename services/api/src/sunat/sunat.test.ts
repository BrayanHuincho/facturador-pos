import { deflateRawSync } from 'node:zlib';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { claseDeCodigo, codigoLimpio, estadoPorCodigo } from './catalogos.js';
import { cdrDeOtroComprobante, clienteDelCdr, codigoDelCdr } from './cdr.js';
import { clasificarRespuesta, decidirTicket } from './clasificacion.js';
import { crearLlamadaGateway, ErrorDatosSunat, ErrorRedSunat, type CredencialesSunat, type RespuestaSunat } from './cliente.js';
import { exigirCredencialesGuia, resolverCredenciales, type FilaConfiguracionSunat } from './credenciales.js';
import { documentoComprobante, type ComprobanteEnvio, type EmpresaSunat } from './documento.js';
import { enviarComprobante, type DepsEnvio } from './envio.js';

const r = (parcial: Partial<RespuestaSunat>): RespuestaSunat => ({ exito: false, notas: [], ...parcial });

afterEach(() => vi.unstubAllGlobals());

describe('clasificación de códigos', () => {
  it.each(['0100', '0109', '0130', '0135', '0138', '0200', '0204', 'HTTP'])('%s es transitorio', (c) => expect(claseDeCodigo(c)).toBe('TRANSITORIO'));
  it.each(['0101', '0106', '0110', '0114'])('%s es de credenciales', (c) => expect(claseDeCodigo(c)).toBe('CREDENCIALES'));

  it('limpia prefijos SOAP y normaliza el cero', () => {
    expect(codigoLimpio('soap-env:Client.0130')).toBe('0130');
    expect(codigoLimpio('00')).toBe('0');
    expect(claseDeCodigo('soap-env:Server.0200')).toBe('TRANSITORIO');
  });

  it('estado según el rango', () => {
    expect(estadoPorCodigo('0', true)).toBe('aceptado');
    expect(estadoPorCodigo('2335', true)).toBe('rechazado');
    expect(estadoPorCodigo('3999', false)).toBe('rechazado');
    expect(estadoPorCodigo('4252', true)).toBe('observado');
    expect(estadoPorCodigo('0102', false)).toBe('error');
  });

  it('decide qué hacer con cada respuesta', () => {
    expect(clasificarRespuesta(r({ error: { codigo: '0130', mensaje: 'x' } }))).toEqual({ tipo: 'reintentar' });
    expect(clasificarRespuesta(r({ codigo: '1033' }))).toEqual({ tipo: 'recuperar_cdr' });
    expect(clasificarRespuesta(r({ codigo: '0102' }))).toEqual({ tipo: 'final', estado: 'error' });
    expect(clasificarRespuesta(r({ codigo: '2800' }))).toEqual({ tipo: 'final', estado: 'rechazado' });
    expect(clasificarRespuesta(r({ exito: true, codigo: '0' }))).toEqual({ tipo: 'final', estado: 'aceptado' });
    expect(clasificarRespuesta(r({ exito: true, codigo: '0', notas: ['4252 - obs'] }))).toEqual({ tipo: 'final', estado: 'aceptado' });
  });

  it('98 es ticket en proceso', () => {
    expect(decidirTicket(r({ estado_ticket: '98' }))).toEqual({ tipo: 'en_proceso' });
    expect(decidirTicket(r({ pendiente: true, codigo: '98' }))).toEqual({ tipo: 'en_proceso' });
    expect(decidirTicket(r({ estado_ticket: '0', cdr: 'x', codigo: '0' }))).toEqual({ tipo: 'final', estado: 'aceptado' });
    expect(decidirTicket(r({ estado_ticket: '99', cdr: 'x', codigo: '2282' }))).toEqual({ tipo: 'final', estado: 'rechazado' });
    expect(decidirTicket(r({ error: { codigo: '0130', mensaje: 'x' } }))).toEqual({ tipo: 'reintentar' });
  });
});

describe('cliente del gateway', () => {
  const llamar = crearLlamadaGateway({ url: 'http://gateway:4210/', token: 'token' });
  const cuerpo = { credenciales: {} as CredencialesSunat, emisor: {} as never, documento: {} };
  const responder = (cuerpoRespuesta: string, status = 200) => vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(cuerpoRespuesta, { status })));

  it('envía X-Token-Interno y devuelve el rechazo', async () => {
    responder(JSON.stringify({ exito: false, codigo: '2335' }));
    expect((await llamar('factura', cuerpo)).codigo).toBe('2335');
    const [url, init] = vi.mocked(fetch).mock.calls[0];
    expect(url).toBe('http://gateway:4210/factura');
    expect((init?.headers as Record<string, string>)['X-Token-Interno']).toBe('token');
  });

  it('distingue red de datos', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('fallo')));
    await expect(llamar('factura', cuerpo)).rejects.toBeInstanceOf(ErrorRedSunat);
    responder('caido', 502);
    await expect(llamar('factura', cuerpo)).rejects.toBeInstanceOf(ErrorRedSunat);
    responder(JSON.stringify({ exito: false, error: { codigo: 'HTTP', mensaje: 'x', red: true } }));
    await expect(llamar('factura', cuerpo)).rejects.toBeInstanceOf(ErrorRedSunat);
    responder(JSON.stringify({ exito: false, error: { codigo: 'DATOS', mensaje: 'x' } }), 422);
    await expect(llamar('factura', cuerpo)).rejects.toBeInstanceOf(ErrorDatosSunat);
    responder('{}', 401);
    await expect(llamar('factura', cuerpo)).rejects.toBeInstanceOf(ErrorDatosSunat);
  });
});

describe('credenciales por entorno', () => {
  const fila: FilaConfiguracionSunat = {
    entorno: 'beta',
    usuario_sol: 'REAL',
    clave_sol_cifrada: 'c:clave-real',
    certificado_cifrado: null,
    gre_client_id: 'id',
    gre_client_secret_cifrado: 'c:secreto',
    envio_boletas: 'individual',
  };
  const demo = { usuario: 'DEMO', clave: 'demo' };
  const abrir = (t: string) => t.slice(2);

  it('beta usa las demo y el certificado propio solo si existe', () => {
    expect(resolverCredenciales(fila, demo, abrir)).toMatchObject({ entorno: 'PRUEBA', usuario_sol: 'DEMO', clave_sol: 'demo', certificado: null });
    expect(resolverCredenciales({ ...fila, certificado_cifrado: 'c:PEM' }, demo, abrir).certificado).toBe('PEM');
  });

  it('producción nunca toma las demo', () => {
    const real = resolverCredenciales({ ...fila, entorno: 'produccion', certificado_cifrado: 'c:PEM' }, demo, abrir);
    expect(real).toMatchObject({ entorno: 'PRODUCCION', usuario_sol: 'REAL', clave_sol: 'clave-real', certificado: 'PEM' });
    expect(() => resolverCredenciales({ ...fila, entorno: 'produccion' }, demo, abrir)).toThrow(ErrorDatosSunat);
    expect(() => resolverCredenciales({ ...fila, entorno: 'produccion', usuario_sol: null, certificado_cifrado: 'c:PEM' }, demo, abrir)).toThrow(ErrorDatosSunat);
  });

  it('la guía en producción exige la API de SUNAT', () => {
    expect(() => exigirCredencialesGuia({ entorno: 'PRODUCCION', usuario_sol: 'a', clave_sol: 'b', certificado: 'c', certificado_clave: null })).toThrow(ErrorDatosSunat);
  });
});

function zipDe(nombre: string, contenido: string): Buffer {
  const datos = deflateRawSync(Buffer.from(contenido));
  const nombreBytes = Buffer.from(nombre);
  const local = Buffer.alloc(30);
  local.writeUInt32LE(0x04034b50, 0);
  local.writeUInt16LE(8, 8);
  local.writeUInt32LE(datos.length, 18);
  local.writeUInt16LE(nombreBytes.length, 26);
  const central = Buffer.alloc(46);
  central.writeUInt32LE(0x02014b50, 0);
  central.writeUInt16LE(8, 10);
  central.writeUInt32LE(datos.length, 20);
  central.writeUInt16LE(nombreBytes.length, 28);
  const inicioCentral = local.length + nombreBytes.length + datos.length;
  const fin = Buffer.alloc(22);
  fin.writeUInt32LE(0x06054b50, 0);
  fin.writeUInt16LE(1, 10);
  fin.writeUInt32LE(inicioCentral, 16);
  return Buffer.concat([local, nombreBytes, datos, central, nombreBytes, fin]);
}

const cdrDe = (cliente: string, codigo = '0') =>
  zipDe('R-1.xml', `<x><cbc:ResponseCode>${codigo}</cbc:ResponseCode><cac:RecipientParty><cac:PartyIdentification><cbc:ID>6-${cliente}</cbc:ID></cac:PartyIdentification></cac:RecipientParty></x>`).toString('base64');

describe('CDR', () => {
  it('lee cliente y código del zip', () => {
    const cdr = cdrDe('20100055237', '4252');
    expect(clienteDelCdr(cdr)).toBe('20100055237');
    expect(codigoDelCdr(cdr)).toBe('4252');
  });

  it('detecta un CDR de otro cliente y no compara clientes varios', () => {
    expect(cdrDeOtroComprobante(cdrDe('20100055237'), '20999999999')).toBe(true);
    expect(cdrDeOtroComprobante(cdrDe('20100055237'), '20100055237')).toBe(false);
    expect(cdrDeOtroComprobante(cdrDe('20100055237'), '00000000')).toBeNull();
  });
});

const empresa: EmpresaSunat = { ruc: '20123456789', razon_social: 'ACME', nombre_comercial: null, direccion: 'Av 1', ubigeo: '150101', departamento: 'LIMA', provincia: 'LIMA', distrito: 'LIMA', igv_porcentaje: '18' };

const comprobante = (parcial: Partial<ComprobanteEnvio> = {}): ComprobanteEnvio => ({
  id: 'c1',
  tipo: '01',
  serie: 'F001',
  correlativo: 7,
  fecha_emision: '2026-11-09',
  hora_emision: '10:00:00.000',
  moneda: 'PEN',
  tipo_cambio: null,
  forma_pago: 'contado',
  cuotas: null,
  cliente_tipo_documento: '6',
  cliente_numero_documento: '20100055237',
  cliente_nombre: 'CLIENTE',
  cliente_direccion: null,
  op_gravadas: '100.00',
  op_exoneradas: '0.00',
  op_inafectas: '0.00',
  op_gratuitas: '0.00',
  descuento_total: '0.00',
  igv: '18.00',
  icbper: '0.50',
  total: '118.50',
  detraccion: null,
  leyendas: [{ codigo: '1000', valor: 'SON CIENTO DIECIOCHO' }],
  afectado_tipo: null,
  afectado_serie: null,
  afectado_correlativo: null,
  motivo_codigo: null,
  motivo_descripcion: null,
  estado: 'pendiente',
  hash: null,
  xml_path: null,
  cdr_path: null,
  pdf_path: null,
  entorno: 'produccion',
  resumen_id: null,
  establecimiento_codigo: '0000',
  items: [{ codigo: 'P1', descripcion: 'Bolsa', unidad: 'NIU', cantidad: '1.0000', precio_unitario: '118.000000', valor_unitario: '100.000000', descuento: '0.00', afectacion: '10', base: '100.00', igv: '18.00', icbper: '0.50', total: '118.50' }],
  ...parcial,
});

const credencialesProduccion: CredencialesSunat = { entorno: 'PRODUCCION', usuario_sol: 'REAL', clave_sol: 'x', certificado: 'PEM', certificado_clave: null };

function armar(respuestas: Record<string, RespuestaSunat | Error>, parcial: Partial<DepsEnvio> = {}, c = comprobante()) {
  const llamar = vi.fn(async (ruta: string) => {
    const salida = respuestas[ruta];
    if (salida instanceof Error) throw salida;
    return salida;
  });
  const actualizar = vi.fn(async () => undefined);
  const deps: DepsEnvio = {
    leerComprobante: async () => c,
    leerContexto: async () => ({ empresa, entorno: 'produccion', envio_boletas: 'individual' }),
    credenciales: async () => credencialesProduccion,
    reclamarEnvio: async () => true,
    actualizar,
    llamar: llamar as unknown as DepsEnvio['llamar'],
    guardar: async (ruta) => ruta,
    generarYGuardarPdf: async () => undefined,
    aviso: () => undefined,
    ...parcial,
  };
  const ultimoEstado = () => (actualizar.mock.calls.at(-1) as unknown[] | undefined)?.[1] as Record<string, unknown>;
  return { deps, llamar, actualizar, ultimoEstado };
}

describe('envío de comprobantes', () => {
  it('guarda XML y CDR y queda aceptado', async () => {
    const { deps, ultimoEstado } = armar({ factura: r({ exito: true, codigo: '0', xml: 'eA==', cdr: 'eQ==', hash: 'H', descripcion: 'ok' }) });
    expect(await enviarComprobante('c1', deps)).toBe('aceptado');
    expect(ultimoEstado()).toMatchObject({ estado: 'aceptado', hash: 'H', xml_path: 'produccion/20123456789/20123456789-01-F001-7.xml', cdr_path: 'produccion/20123456789/R-20123456789-01-F001-7.xml' });
  });

  it('un código transitorio devuelve a pendiente y reintenta', async () => {
    const { deps, ultimoEstado } = armar({ factura: r({ error: { codigo: '0130', mensaje: 'x' } }) });
    await expect(enviarComprobante('c1', deps)).rejects.toBeInstanceOf(ErrorRedSunat);
    expect(ultimoEstado().estado).toBe('pendiente');
  });

  it('credenciales incorrectas: error sin reintento', async () => {
    const { deps, ultimoEstado } = armar({ factura: r({ codigo: '0102', descripcion: 'x' }) });
    expect(await enviarComprobante('c1', deps)).toBe('error');
    expect(ultimoEstado().estado).toBe('error');
  });

  it('no envía si otro trabajo ya lo reclamó y pide reintentar', async () => {
    const { deps, llamar } = armar({}, { reclamarEnvio: async () => false });
    await expect(enviarComprobante('c1', deps)).rejects.toThrow(/ya se está enviando/);
    expect(llamar).not.toHaveBeenCalled();
  });

  it.each(['aceptado', 'observado', 'rechazado', 'anulado'])('nunca reenvía uno %s', async (estado) => {
    const { deps, llamar } = armar({}, {}, comprobante({ estado }));
    expect(await enviarComprobante('c1', deps)).toBe(estado);
    expect(llamar).not.toHaveBeenCalled();
  });

  it('no envía a producción un comprobante emitido en beta', async () => {
    const { deps, llamar, ultimoEstado } = armar({}, {}, comprobante({ entorno: 'beta' }));
    expect(await enviarComprobante('c1', deps)).toBe('error');
    expect(llamar).not.toHaveBeenCalled();
    expect(ultimoEstado().estado).toBe('error');
  });

  it('si falla Storage el estado de SUNAT no se pierde', async () => {
    const { deps, ultimoEstado } = armar({ factura: r({ exito: true, codigo: '0', xml: 'eA==' }) }, { guardar: async () => { throw new Error('storage'); } });
    expect(await enviarComprobante('c1', deps)).toBe('aceptado');
    expect(ultimoEstado()).toMatchObject({ estado: 'aceptado', xml_path: null });
  });

  it('boleta por resumen solo se firma', async () => {
    const { deps, llamar, ultimoEstado } = armar(
      { firmar: r({ exito: true, xml: 'eA==', hash: 'H' }) },
      { leerContexto: async () => ({ empresa, entorno: 'produccion', envio_boletas: 'resumen_diario' }) },
      comprobante({ tipo: '03', serie: 'B001' }),
    );
    expect(await enviarComprobante('c1', deps)).toBe('por_resumen');
    expect(llamar.mock.calls.map(([ruta]) => ruta)).toEqual(['firmar']);
    expect(ultimoEstado()).toMatchObject({ hash: 'H' });
  });
});

describe('recuperación por 1033', () => {
  const ya = r({ codigo: '1033', descripcion: 'ya presentado', xml: 'eA==', hash: 'H' });

  it('recupera con la consulta y usa el código del CDR, no el de la consulta', async () => {
    const { deps, llamar, ultimoEstado } = armar({ factura: ya, 'consulta-cpe': r({ exito: true, codigo: '0004', cdr: cdrDe('20100055237'), cdr_codigo: '0', cdr_descripcion: 'aceptada' }) });
    expect(await enviarComprobante('c1', deps)).toBe('aceptado');
    expect(llamar.mock.calls.map(([ruta]) => ruta)).toEqual(['factura', 'consulta-cpe']);
    expect(ultimoEstado()).toMatchObject({ estado: 'aceptado', sunat_codigo: '0', hash: 'H' });
  });

  it('sin cdr_codigo lo lee del propio CDR y nunca asume aceptado', async () => {
    const { deps, ultimoEstado } = armar({ factura: ya, 'consulta-cpe': r({ exito: true, codigo: '0004', cdr: cdrDe('20100055237', '2800') }) });
    expect(await enviarComprobante('c1', deps)).toBe('rechazado');
    expect(ultimoEstado().sunat_codigo).toBe('2800');
  });

  it('rechaza el CDR de otro cliente', async () => {
    const { deps, ultimoEstado } = armar({ factura: ya, 'consulta-cpe': r({ exito: true, cdr: cdrDe('20999999999'), cdr_codigo: '0' }) });
    expect(await enviarComprobante('c1', deps)).toBe('error');
    expect(ultimoEstado().sunat_descripcion).toMatch(/otro cliente/);
  });

  it('una caída de red en la consulta reintenta', async () => {
    const { deps, ultimoEstado } = armar({ factura: ya, 'consulta-cpe': new ErrorRedSunat('red') });
    await expect(enviarComprobante('c1', deps)).rejects.toBeInstanceOf(ErrorRedSunat);
    expect(ultimoEstado().estado).toBe('pendiente');
  });

  it('en beta no consulta y queda en error', async () => {
    const { deps, llamar } = armar({ factura: ya }, { credenciales: async () => ({ ...credencialesProduccion, entorno: 'PRUEBA' }) });
    expect(await enviarComprobante('c1', deps)).toBe('error');
    expect(llamar).toHaveBeenCalledTimes(1);
  });
});

describe('documento para el gateway', () => {
  it('incluye ICBPER en impuestos y conserva el formato', () => {
    const { ruta, documento } = documentoComprobante(comprobante(), '18');
    expect(ruta).toBe('factura');
    expect(documento).toMatchObject({ tipo_documento: '01', correlativo: '7', hora_emision: '10:00:00', forma_pago: 'CONTADO', tipo_operacion: '0101', totales: { total_impuestos: 18.5, valor_venta: 100, total: 118.5 } });
    expect((documento.items as Record<string, unknown>[])[0]).toMatchObject({ factor_icbper: 0.5, total_impuestos: 18.5, porcentaje_igv: 18 });
  });

  it('nota con referencia y sin AllowanceCharge', () => {
    const item = { ...comprobante().items[0], cantidad: '2.0000', valor_unitario: '60.000000', descuento: '20.00', base: '100.00' };
    const nota = documentoComprobante(comprobante({ tipo: '07', serie: 'FC01', afectado_tipo: '01', afectado_serie: 'F001', afectado_correlativo: 3, motivo_codigo: '01', motivo_descripcion: 'x', items: [item] }), '18');
    expect(nota.ruta).toBe('nota');
    expect(nota.documento.num_doc_afectado).toBe('F001-000003');
    expect((nota.documento.items as Record<string, unknown>[])[0]).toMatchObject({ valor_unitario: 50 });
    expect((nota.documento.items as Record<string, unknown>[])[0].descuento).toBeUndefined();
    const factura = documentoComprobante(comprobante({ items: [item] }), '18');
    expect((factura.documento.items as Record<string, unknown>[])[0]).toMatchObject({ valor_unitario: 60, descuento: { base: 120, monto: 20, factor: 0.16667 } });
  });
});
