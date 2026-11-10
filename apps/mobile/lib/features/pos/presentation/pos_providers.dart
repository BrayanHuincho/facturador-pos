import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/api_client.dart';
import '../data/almacen_cola_prefs.dart';
import '../data/catalogo_repository.dart';
import '../data/pos_api.dart';
import '../domain/carrito.dart';
import '../domain/catalogo_pos.dart';
import '../domain/cola_checkout.dart';

const _intervaloSincronizacion = Duration(seconds: 30);

final catalogoRepositoryProvider = Provider(
  (ref) => CatalogoRepository(Supabase.instance.client),
);

final posApiProvider = Provider((ref) => PosApi(ref.watch(apiClientProvider)));

final catalogoProvider = FutureProvider<Catalogo>(
  (ref) => ref.watch(catalogoRepositoryProvider).cargar(),
);

final empresaTicketProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(catalogoRepositoryProvider).empresa(),
);

final comprobanteEnVivoProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, id) => ref.watch(catalogoRepositoryProvider).comprobanteEnVivo(id),
    );

final consultaProductoProvider =
    NotifierProvider<ConsultaProductoNotifier, String>(
      ConsultaProductoNotifier.new,
    );

class ConsultaProductoNotifier extends Notifier<String> {
  @override
  String build() => '';

  void fijar(String valor) => state = valor;
}

final categoriaSeleccionadaProvider =
    NotifierProvider<CategoriaSeleccionadaNotifier, String?>(
      CategoriaSeleccionadaNotifier.new,
    );

class CategoriaSeleccionadaNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void fijar(String? valor) => state = valor;
}

final carritoProvider = NotifierProvider<CarritoNotifier, Carrito>(
  CarritoNotifier.new,
);

class CarritoNotifier extends Notifier<Carrito> {
  @override
  Carrito build() => const Carrito();

  void agregar(ProductoPos producto) => state = state.agregar(producto);

  void fijarCantidad(String id, Decimal cantidad) =>
      state = state.fijarCantidad(id, cantidad);

  void fijarDescuento(String id, Decimal descuento) =>
      state = state.fijarDescuento(id, descuento);

  void quitar(String id) => state = state.quitar(id);

  void limpiar() => state = const Carrito();

  void restaurar(Carrito previo) => state = previo;
}

final usuarioIdProvider = StreamProvider<String?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentUser?.id;
  yield* auth.onAuthStateChange.map((e) => e.session?.user.id).distinct();
});

final colaCheckoutProvider = Provider<ColaCheckout?>((ref) {
  final usuarioId = ref.watch(usuarioIdProvider.select((u) => u.value));
  if (usuarioId == null) return null;
  final cola = ColaCheckout(
    almacen: AlmacenColaPrefs(usuarioId),
    emisor: ref.watch(posApiProvider),
  );
  ref.onDispose(cola.cerrar);
  return cola;
});

final entradasColaProvider = StreamProvider<List<EntradaCola>>((ref) async* {
  final cola = ref.watch(colaCheckoutProvider);
  if (cola == null) {
    yield const [];
    return;
  }
  await cola.cargar();
  yield cola.entradas;
  yield* cola.cambios;
});

final sincronizadorColaProvider = Provider<void>((ref) {
  final cola = ref.watch(colaCheckoutProvider);
  if (cola == null) return;
  final conectividad = Connectivity();

  Future<void> intentar() async {
    final estado = await conectividad.checkConnectivity();
    if (estado.every((e) => e == ConnectivityResult.none)) return;
    await cola.vaciar();
  }

  final suscripcion = conectividad.onConnectivityChanged.listen((estado) {
    if (estado.any((e) => e != ConnectivityResult.none)) {
      unawaited(cola.vaciar());
    }
  });
  final temporizador = Timer.periodic(
    _intervaloSincronizacion,
    (_) => unawaited(intentar()),
  );
  unawaited(intentar());
  ref.onDispose(() {
    suscripcion.cancel();
    temporizador.cancel();
  });
});
