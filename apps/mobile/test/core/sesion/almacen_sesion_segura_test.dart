import 'package:facturador_pos/core/sesion/almacen_sesion_segura.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final inicio = DateTime.utc(2026, 11, 1, 12);

  AlmacenSesionSegura almacenEn(DateTime instante) =>
      AlmacenSesionSegura(reloj: () => instante);

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('el plazo de 7 días se cumple desde el inicio de sesión', () {
    expect(sesionVencida(inicio, inicio.add(const Duration(days: 6))), isFalse);
    expect(sesionVencida(inicio, inicio.add(const Duration(days: 7))), isTrue);
  });

  test('recordada: dura 7 días y luego exige ingresar', () async {
    final almacen = almacenEn(inicio);
    await almacen.prepararInicio(recordar: true);
    await almacen.persistSession('sesion');
    await almacen.registrarInicio(recordar: true, correo: 'a@b.pe');

    final enPlazo = almacenEn(inicio.add(const Duration(days: 6)));
    await enPlazo.initialize();
    expect(await enPlazo.accessToken(), 'sesion');

    final vencida = almacenEn(inicio.add(const Duration(days: 8)));
    await vencida.initialize();
    expect(await vencida.accessToken(), isNull);
    expect(await vencida.correoRecordado(), 'a@b.pe');
  });

  test('sin recordar: no queda sesión al reiniciar la app', () async {
    final almacen = almacenEn(inicio);
    await almacen.prepararInicio(recordar: false);
    await almacen.persistSession('sesion');
    await almacen.registrarInicio(recordar: false, correo: 'a@b.pe');
    expect(await almacen.accessToken(), 'sesion');

    final reinicio = almacenEn(inicio.add(const Duration(minutes: 5)));
    await reinicio.initialize();
    expect(await reinicio.accessToken(), isNull);
    expect(await reinicio.correoRecordado(), isNull);
  });
}
