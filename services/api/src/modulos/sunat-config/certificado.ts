import forge from 'node-forge';
import { ErrorApi } from '../../http/errores.js';

export type CertificadoLeido = {
  pem: string;
  sujeto: string;
  emisor: string;
  titular: string;
  ruc: string | null;
  serie: string;
  valido_desde: Date;
  vence_en: Date;
};

const PRIMER_BYTE_DER = 0x30;
const FORMATO_RUC = /\b(10|15|16|17|20)\d{9}\b/;

const error = (codigo: string, mensaje: string) => new ErrorApi(400, codigo, mensaje);
const claveIncorrecta = () => error('CLAVE_CERTIFICADO_INCORRECTA', 'La contraseña del certificado no es correcta.');

function nombreDe(atributos: forge.pki.CertificateField[]): string {
  return atributos.map((a) => `${a.shortName ?? a.name ?? a.type}=${String(a.value)}`).join(', ');
}

function rucDe(certificado: forge.pki.Certificate): string | null {
  for (const atributo of certificado.subject.attributes) {
    const encontrado = FORMATO_RUC.exec(String(atributo.value ?? ''));
    if (encontrado) return encontrado[0];
  }
  return null;
}

function titularDe(certificado: forge.pki.Certificate, sujeto: string): string {
  return String(certificado.subject.getField('CN')?.value ?? certificado.subject.getField('O')?.value ?? sujeto);
}

function componer(clave: forge.pki.PrivateKey, cadena: forge.pki.Certificate[]): CertificadoLeido {
  const privada = clave as forge.pki.rsa.PrivateKey;
  const huella = forge.pki.publicKeyToPem(forge.pki.rsa.setPublicKey(privada.n, privada.e));
  const propio = cadena.find((c) => forge.pki.publicKeyToPem(c.publicKey as forge.pki.rsa.PublicKey) === huella);
  if (!propio) throw error('CERTIFICADO_SIN_PAREJA', 'La clave privada no corresponde a ningún certificado del archivo.');
  const resto = cadena.filter((c) => c !== propio);
  const pem = [forge.pki.privateKeyToPem(clave), forge.pki.certificateToPem(propio), ...resto.map((c) => forge.pki.certificateToPem(c))]
    .map((bloque) => bloque.trim())
    .join('\n');
  const sujeto = nombreDe(propio.subject.attributes);
  return {
    pem: `${pem}\n`,
    sujeto,
    emisor: nombreDe(propio.issuer.attributes),
    titular: titularDe(propio, sujeto),
    ruc: rucDe(propio),
    serie: propio.serialNumber,
    valido_desde: propio.validity.notBefore,
    vence_en: propio.validity.notAfter,
  };
}

function leerPfx(datos: Buffer, clave: string): CertificadoLeido {
  let p12: forge.pkcs12.Pkcs12Pfx;
  try {
    const asn1 = forge.asn1.fromDer(forge.util.createBuffer(datos.toString('binary')));
    p12 = forge.pkcs12.pkcs12FromAsn1(asn1, false, clave);
  } catch (e) {
    const mensaje = e instanceof Error ? e.message : '';
    if (/password|decrypt|\bMAC\b/i.test(mensaje)) throw claveIncorrecta();
    throw error('CERTIFICADO_INVALIDO', 'El archivo no es un certificado .pfx/.p12 válido.');
  }
  const oids = forge.pki.oids;
  const bolsasClave = [
    ...(p12.getBags({ bagType: oids.pkcs8ShroudedKeyBag! })[oids.pkcs8ShroudedKeyBag!] ?? []),
    ...(p12.getBags({ bagType: oids.keyBag! })[oids.keyBag!] ?? []),
  ];
  const privada = bolsasClave.find((bolsa) => bolsa.key)?.key;
  const certificados = (p12.getBags({ bagType: oids.certBag! })[oids.certBag!] ?? [])
    .map((bolsa) => bolsa.cert)
    .filter((c): c is forge.pki.Certificate => Boolean(c));
  if (!privada) throw error('CERTIFICADO_SIN_CLAVE', 'El archivo no trae la clave privada: exporta el .pfx incluyéndola.');
  if (!certificados.length) throw error('CERTIFICADO_INVALIDO', 'El archivo no trae ningún certificado.');
  return componer(privada, certificados);
}

function descifrarClavePem(bloque: string, clave: string): forge.pki.PrivateKey {
  let privada: forge.pki.PrivateKey | null;
  try {
    privada = forge.pki.decryptRsaPrivateKey(bloque, clave);
  } catch {
    throw claveIncorrecta();
  }
  if (!privada) throw claveIncorrecta();
  return privada;
}

function leerPem(texto: string, clave: string): CertificadoLeido {
  const bloques = texto.match(/-----BEGIN [A-Z ]+-----[\s\S]+?-----END [A-Z ]+-----/g) ?? [];
  const certificados: forge.pki.Certificate[] = [];
  let privada: forge.pki.PrivateKey | null = null;
  for (const bloque of bloques) {
    if (bloque.includes('CERTIFICATE-----')) {
      certificados.push(forge.pki.certificateFromPem(bloque));
    } else if (bloque.includes('ENCRYPTED PRIVATE KEY') || bloque.includes('Proc-Type: 4,ENCRYPTED')) {
      privada = descifrarClavePem(bloque, clave);
    } else if (bloque.includes('PRIVATE KEY')) {
      privada = forge.pki.privateKeyFromPem(bloque);
    }
  }
  if (!certificados.length) throw error('CERTIFICADO_INVALIDO', 'El archivo PEM no trae ningún certificado.');
  if (!privada) throw error('CERTIFICADO_SIN_CLAVE', 'El PEM no trae la clave privada: SUNAT la necesita para firmar.');
  return componer(privada, certificados);
}

function esPem(datos: Buffer): boolean {
  return datos[0] !== PRIMER_BYTE_DER && datos.includes('-----BEGIN');
}

export function leerCertificado(datos: Buffer, clave = ''): CertificadoLeido {
  if (!datos.length) throw error('CERTIFICADO_VACIO', 'El archivo está vacío.');
  try {
    return esPem(datos) ? leerPem(datos.toString('utf8'), clave) : leerPfx(datos, clave);
  } catch (e) {
    if (e instanceof ErrorApi) throw e;
    throw error('CERTIFICADO_INVALIDO', 'No se pudo leer el certificado. Sube un .pfx/.p12 con su contraseña o un .pem con la clave privada.');
  }
}
