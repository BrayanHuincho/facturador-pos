import 'dart:async';

import 'package:facturador_pos/features/pos/domain/cola_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

class AlmacenMemoria implements AlmacenCola {
  String? contenido;

  @override
  Future<String?> leer() async => contenido;

  @override
  Future<void> escribir(String valor) async => contenido = valor;
}

class EmisorFalso implements EmisorCheckout {
  final List<String> claves = [];
  final List<Object> fallos = [];
  Completer<void>? bloqueo;

  @override
  Future<Map<String, dynamic>> emitir(
    String clave,
    Map<String, dynamic> cuerpo,
  ) async {
    claves.add(clave);
    if (bloqueo != null) await bloqueo!.future;
    if (fallos.isNotEmpty) throw fallos.removeAt(0);
    return {'id': 'comprobante-$clave'};
  }
}

void main() {
  late AlmacenMemoria almacen;
  late EmisorFalso emisor;
  late ColaCheckout cola;

  ColaCheckout nuevaCola() => ColaCheckout(almacen: almacen, emisor: emisor);

  setUp(() {
    almacen = AlmacenMemoria();
    emisor = EmisorFalso();
    cola = nuevaCola();
  });

  test('persiste antes de enviar y borra al confirmar', () async {
    await cola.encolar('k1', {'tipo': '03'});
    expect(almacen.contenido, contains('k1'));
    final resultado = await cola.enviar('k1');
    expect(resultado, isA<EnvioExitoso>());
    expect(cola.entradas, isEmpty);
    expect(almacen.contenido, isNot(contains('k1')));
  });

  test('un fallo inesperado no se guarda como venta en cola', () async {
    emisor.fallos.add(StateError('json inesperado'));
    await cola.encolar('k1', {});
    final resultado = await cola.enviar('k1');
    expect(resultado, isA<EnvioRechazado>());
    expect(cola.entradas.single.estado, EstadoEntradaCola.rechazada);
  });

  test('encolar dos veces la misma clave no duplica', () async {
    await cola.encolar('k1', {});
    await cola.encolar('k1', {});
    expect(cola.entradas, hasLength(1));
  });

  test('un fallo transitorio conserva la clave entre reintentos', () async {
    emisor.fallos.add(const FalloTransitorio('sin red'));
    await cola.encolar('k1', {});
    expect(await cola.enviar('k1'), isA<EnvioEnEspera>());
    expect(cola.entradas.single.intentos, 1);
    await cola.vaciar();
    expect(emisor.claves, ['k1', 'k1']);
    expect(cola.entradas, isEmpty);
  });

  test('sobrevive a un reinicio con la misma clave y cuerpo', () async {
    emisor.fallos.add(const FalloTransitorio('sin red'));
    await cola.encolar('k1', {'tipo': '01'});
    await cola.enviar('k1');

    final reiniciada = nuevaCola();
    await reiniciada.cargar();
    expect(reiniciada.entradas.single.cuerpo, {'tipo': '01'});
    await reiniciada.vaciar();
    expect(emisor.claves, ['k1', 'k1']);
    expect(reiniciada.entradas, isEmpty);
  });

  test('envios concurrentes de una clave emiten una sola vez', () async {
    emisor.bloqueo = Completer<void>();
    await cola.encolar('k1', {});
    final primero = cola.enviar('k1');
    final segundo = cola.enviar('k1');
    final vaciado = cola.vaciar();
    await Future<void>.delayed(Duration.zero);
    emisor.bloqueo!.complete();
    await Future.wait([primero, segundo, vaciado]);
    expect(emisor.claves, ['k1']);
  });

  test('vaciar respeta el orden y se detiene en el primer transitorio', () async {
    await cola.encolar('k1', {});
    await cola.encolar('k2', {});
    emisor.fallos.add(const FalloTransitorio('caido'));
    await cola.vaciar();
    expect(emisor.claves, ['k1']);
    expect(cola.entradas.map((e) => e.clave), ['k1', 'k2']);
  });

  test('un rechazo definitivo no se reintenta y no bloquea las demas', () async {
    await cola.encolar('k1', {});
    await cola.encolar('k2', {});
    emisor.fallos.add(const FalloDefinitivo('turno cerrado'));
    await cola.vaciar();
    expect(cola.entradas.single.estado, EstadoEntradaCola.rechazada);
    expect(cola.entradas.single.clave, 'k1');
    expect(emisor.claves, ['k1', 'k2']);
    await cola.vaciar();
    expect(emisor.claves, ['k1', 'k2']);
  });

  test('reintentar una rechazada usa la misma clave', () async {
    emisor.fallos.add(const FalloDefinitivo('turno cerrado'));
    await cola.encolar('k1', {});
    await cola.enviar('k1');
    await cola.reintentar('k1');
    expect(emisor.claves, ['k1', 'k1']);
    expect(cola.entradas, isEmpty);
  });

  test('emite evento con el comprobante al vaciar', () async {
    await cola.encolar('k1', {});
    final evento = cola.eventos.first;
    await cola.vaciar();
    final recibido = await evento;
    expect(recibido, isA<EnvioExitoso>());
    expect((recibido as EnvioExitoso).comprobante['id'], 'comprobante-k1');
  });
}
