import forge from 'node-forge';
import { beforeAll, describe, expect, it } from 'vitest';
import { ErrorApi } from '../../http/errores.js';
import { leerCertificado } from './certificado.js';
import { validarCertificadoParaEmpresa, validarPasoProduccion } from './reglas.js';

const RUC = '20606883537';
const OTRO_RUC = '20100070970';
const DIA = 86_400_000;
const CLAVE = 'clave-del-pfx';

const pares: forge.pki.rsa.KeyPair[] = [];

beforeAll(() => {
  pares.push(forge.pki.rsa.generateKeyPair({ bits: 1024, e: 0x10001 }), forge.pki.rsa.generateKeyPair({ bits: 1024, e: 0x10001 }));
});

function certificado(par: forge.pki.rsa.KeyPair, ruc = RUC, desdeDias = -1, hastaDias = 365) {
  const cert = forge.pki.createCertificate();
  cert.publicKey = par.publicKey;
  cert.serialNumber = '0a1b2c';
  cert.validity.notBefore = new Date(Date.now() + desdeDias * DIA);
  cert.validity.notAfter = new Date(Date.now() + hastaDias * DIA);
  const atributos = [
    { shortName: 'CN', value: `EMPRESA DE PRUEBA ${ruc}` },
    { shortName: 'O', value: 'EMPRESA DE PRUEBA SAC' },
    { shortName: 'C', value: 'PE' },
  ];
  cert.setSubject(atributos);
  cert.setIssuer(atributos);
  cert.sign(par.privateKey, forge.md.sha256.create());
  return cert;
}

function pfx(par: forge.pki.rsa.KeyPair, cert: forge.pki.Certificate, clave = CLAVE): Buffer {
  const asn1 = forge.pkcs12.toPkcs12Asn1(par.privateKey, [cert], clave, { algorithm: '3des' });
  return Buffer.from(forge.asn1.toDer(asn1).getBytes(), 'binary');
}

function pemDe(par: forge.pki.rsa.KeyPair, cert: forge.pki.Certificate): string {
  return `${forge.pki.privateKeyToPem(par.privateKey)}\n${forge.pki.certificateToPem(cert)}`;
}

function codigoDe(accion: () => unknown): string {
  try {
    accion();
  } catch (e) {
    if (e instanceof ErrorApi) return e.codigo;
    throw e;
  }
  return 'SIN_ERROR';
}

describe('leerCertificado', () => {
  it('lee un PFX, extrae titular, RUC y vencimiento, y descarta la contraseña', () => {
    const par = pares[0]!;
    const leido = leerCertificado(pfx(par, certificado(par)), CLAVE);
    expect(leido.ruc).toBe(RUC);
    expect(leido.titular).toContain('EMPRESA DE PRUEBA');
    expect(leido.vence_en.getTime()).toBeGreaterThan(Date.now());
    expect(leido.pem).toContain('PRIVATE KEY');
    expect(leido.pem).toContain('BEGIN CERTIFICATE');
    expect(leido.pem).not.toContain('ENCRYPTED');
    expect(JSON.stringify(leido)).not.toContain(CLAVE);
  });

  it('rechaza un PFX con contraseña incorrecta', () => {
    const par = pares[0]!;
    expect(codigoDe(() => leerCertificado(pfx(par, certificado(par)), 'otra')) ).toBe('CLAVE_CERTIFICADO_INCORRECTA');
  });

  it('detecta PEM por contenido, incluso con preámbulo largo de atributos', () => {
    const par = pares[0]!;
    const preambulo = `Bag Attributes\n    friendlyName: ${'x'.repeat(120)}\n`;
    expect(leerCertificado(Buffer.from(preambulo + pemDe(par, certificado(par)))).ruc).toBe(RUC);
  });

  it('lee un PEM con clave cifrada y exige su contraseña', () => {
    const par = pares[0]!;
    const cifrada = forge.pki.encryptRsaPrivateKey(par.privateKey, CLAVE, { algorithm: 'aes256' });
    const archivo = Buffer.from(`${cifrada}\n${forge.pki.certificateToPem(certificado(par))}`);
    expect(leerCertificado(archivo, CLAVE).pem).not.toContain('ENCRYPTED');
    expect(codigoDe(() => leerCertificado(archivo, 'otra'))).toBe('CLAVE_CERTIFICADO_INCORRECTA');
  });

  it('rechaza una clave que no es pareja del certificado', () => {
    const archivo = Buffer.from(`${forge.pki.privateKeyToPem(pares[1]!.privateKey)}\n${forge.pki.certificateToPem(certificado(pares[0]!))}`);
    expect(codigoDe(() => leerCertificado(archivo))).toBe('CERTIFICADO_SIN_PAREJA');
  });

  it('rechaza PEM sin clave, archivos vacíos y basura', () => {
    expect(codigoDe(() => leerCertificado(Buffer.from(forge.pki.certificateToPem(certificado(pares[0]!)))))).toBe('CERTIFICADO_SIN_CLAVE');
    expect(codigoDe(() => leerCertificado(Buffer.alloc(0)))).toBe('CERTIFICADO_VACIO');
    expect(codigoDe(() => leerCertificado(Buffer.from('no soy un certificado')))).toBe('CERTIFICADO_INVALIDO');
  });
});

describe('validarCertificadoParaEmpresa', () => {
  const leer = (ruc: string, desde: number, hasta: number) => leerCertificado(Buffer.from(pemDe(pares[0]!, certificado(pares[0]!, ruc, desde, hasta))));

  it('acepta uno vigente del RUC de la empresa', () => {
    expect(codigoDe(() => validarCertificadoParaEmpresa(leer(RUC, -1, 30), RUC, new Date()))).toBe('SIN_ERROR');
  });

  it('rechaza vencido, aún no vigente y de otro RUC', () => {
    expect(codigoDe(() => validarCertificadoParaEmpresa(leer(RUC, -30, -1), RUC, new Date()))).toBe('CERTIFICADO_VENCIDO');
    expect(codigoDe(() => validarCertificadoParaEmpresa(leer(RUC, 2, 30), RUC, new Date()))).toBe('CERTIFICADO_AUN_NO_VIGENTE');
    expect(codigoDe(() => validarCertificadoParaEmpresa(leer(OTRO_RUC, -1, 30), RUC, new Date()))).toBe('CERTIFICADO_DE_OTRO_RUC');
  });
});

describe('validarPasoProduccion', () => {
  const base = () => ({
    rucEmpresa: RUC as string | null,
    confirmarRuc: RUC as string | undefined,
    usuarioSol: 'USUARIO1' as string | null,
    tieneClaveSol: true,
    pemCertificado: pemDe(pares[0]!, certificado(pares[0]!)) as string | null,
    ahora: new Date(),
  });

  it('permite el paso con todo completo', () => {
    expect(codigoDe(() => validarPasoProduccion(base()))).toBe('SIN_ERROR');
  });

  it('exige empresa configurada y confirmación exacta del RUC', () => {
    expect(codigoDe(() => validarPasoProduccion({ ...base(), rucEmpresa: null }))).toBe('EMPRESA_NO_CONFIGURADA');
    expect(codigoDe(() => validarPasoProduccion({ ...base(), rucEmpresa: '20000000001', confirmarRuc: '20000000001' }))).toBe('RUC_DE_PRUEBA');
    expect(codigoDe(() => validarPasoProduccion({ ...base(), confirmarRuc: undefined }))).toBe('CONFIRMACION_RUC_INVALIDA');
    expect(codigoDe(() => validarPasoProduccion({ ...base(), confirmarRuc: OTRO_RUC }))).toBe('CONFIRMACION_RUC_INVALIDA');
  });

  it('exige usuario, clave y certificado', () => {
    expect(codigoDe(() => validarPasoProduccion({ ...base(), usuarioSol: null }))).toBe('SUNAT_INCOMPLETO');
    expect(codigoDe(() => validarPasoProduccion({ ...base(), tieneClaveSol: false }))).toBe('SUNAT_INCOMPLETO');
    expect(codigoDe(() => validarPasoProduccion({ ...base(), pemCertificado: null }))).toBe('SUNAT_INCOMPLETO');
  });

  it('rechaza certificado vencido o de otro RUC', () => {
    const vencido = pemDe(pares[0]!, certificado(pares[0]!, RUC, -30, -1));
    const ajeno = pemDe(pares[0]!, certificado(pares[0]!, OTRO_RUC));
    expect(codigoDe(() => validarPasoProduccion({ ...base(), pemCertificado: vencido }))).toBe('CERTIFICADO_VENCIDO');
    expect(codigoDe(() => validarPasoProduccion({ ...base(), pemCertificado: ajeno }))).toBe('CERTIFICADO_DE_OTRO_RUC');
  });
});
