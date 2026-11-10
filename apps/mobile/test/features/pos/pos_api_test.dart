import 'package:facturador_pos/core/api/api_client.dart';
import 'package:facturador_pos/features/pos/data/pos_api.dart';
import 'package:facturador_pos/features/pos/domain/cola_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin respuesta del servidor el envio es reintentable', () {
    expect(
      clasificarError(const ApiException('SIN_CONEXION', 'x')),
      isA<FalloTransitorio>(),
    );
  });

  test('sesion vencida y errores 5xx son reintentables', () {
    for (final status in [401, 408, 425, 429, 500, 503]) {
      expect(
        clasificarError(ApiException('E', 'x', status: status)),
        isA<FalloTransitorio>(),
      );
    }
  });

  test('las reglas de negocio son rechazos definitivos', () {
    for (final status in [400, 403, 404, 409, 422]) {
      expect(
        clasificarError(ApiException('E', 'x', status: status)),
        isA<FalloDefinitivo>(),
      );
    }
  });
}
