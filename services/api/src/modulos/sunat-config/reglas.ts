import { ErrorApi } from '../../http/errores.js';
import { leerCertificado } from './certificado.js';
import type { CertificadoLeido } from './certificado.js';

const RUC_DE_PRUEBA = '20000000001';

const fechaCorta = (fecha: Date) => fecha.toISOString().slice(0, 10);

export function validarCertificadoParaEmpresa(certificado: CertificadoLeido, rucEmpresa: string, ahora: Date) {
  if (certificado.vence_en.getTime() < ahora.getTime()) {
    throw new ErrorApi(400, 'CERTIFICADO_VENCIDO', `El certificado venció el ${fechaCorta(certificado.vence_en)}.`);
  }
  if (certificado.valido_desde.getTime() > ahora.getTime()) {
    throw new ErrorApi(400, 'CERTIFICADO_AUN_NO_VIGENTE', `El certificado es válido desde el ${fechaCorta(certificado.valido_desde)}.`);
  }
  if (certificado.ruc && certificado.ruc !== rucEmpresa) {
    throw new ErrorApi(400, 'CERTIFICADO_DE_OTRO_RUC', `El certificado es del RUC ${certificado.ruc} y la empresa tiene el RUC ${rucEmpresa}.`);
  }
}

export type EstadoPasoProduccion = {
  rucEmpresa: string | null;
  confirmarRuc: string | undefined;
  usuarioSol: string | null;
  tieneClaveSol: boolean;
  pemCertificado: string | null;
  ahora: Date;
};

export function validarPasoProduccion(estado: EstadoPasoProduccion) {
  if (!estado.rucEmpresa) {
    throw new ErrorApi(409, 'EMPRESA_NO_CONFIGURADA', 'Registra primero los datos de la empresa.');
  }
  if (estado.rucEmpresa === RUC_DE_PRUEBA) {
    throw new ErrorApi(409, 'RUC_DE_PRUEBA', 'Registra el RUC real de tu empresa antes de pasar a producción.');
  }
  if (estado.confirmarRuc !== estado.rucEmpresa) {
    throw new ErrorApi(400, 'CONFIRMACION_RUC_INVALIDA', 'El RUC de confirmación no coincide con el de la empresa.');
  }
  if (!estado.usuarioSol || !estado.tieneClaveSol || !estado.pemCertificado) {
    throw new ErrorApi(400, 'SUNAT_INCOMPLETO', 'Para pasar a producción hacen falta el usuario y la clave SOL y un certificado digital vigente.');
  }
  validarCertificadoParaEmpresa(leerCertificado(Buffer.from(estado.pemCertificado, 'utf8')), estado.rucEmpresa, estado.ahora);
}
