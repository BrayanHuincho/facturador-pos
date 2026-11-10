import 'package:facturador_pos/features/ajustes/domain/ajustes_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const estado = EstadoSunat(
    entorno: 'beta',
    usuarioSol: 'USUARIO',
    tieneClaveSol: true,
    tieneCertificado: true,
    certificadoVenceEn: null,
    certificadoTitular: null,
    tieneGre: false,
    envioBoletas: 'individual',
  );

  test('el RUC de prueba bloquea el paso a producción', () {
    expect(
      estado.requisitosFaltantes(
        rucEmpresa: rucEmpresaDePrueba,
        ahora: DateTime(2026),
      ),
      contains(RequisitoProduccion.rucDePrueba),
    );
  });

  test('un RUC real sin faltantes queda habilitado', () {
    expect(
      estado.requisitosFaltantes(
        rucEmpresa: '20100070970',
        ahora: DateTime(2026),
      ),
      isEmpty,
    );
  });
}
