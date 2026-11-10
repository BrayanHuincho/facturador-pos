import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/cambios_tabla.dart';
import '../data/comprobantes_repository.dart';
import '../domain/comprobante.dart';

class ListadoComprobantes {
  const ListadoComprobantes({
    this.filtros = const FiltrosComprobantes(),
    this.items = const [],
    this.cargando = false,
    this.hayMas = true,
    this.error,
  });

  final FiltrosComprobantes filtros;
  final List<Comprobante> items;
  final bool cargando;
  final bool hayMas;
  final Object? error;

  ListadoComprobantes copiar({
    FiltrosComprobantes? filtros,
    List<Comprobante>? items,
    bool? cargando,
    bool? hayMas,
    Object? error,
  }) => ListadoComprobantes(
    filtros: filtros ?? this.filtros,
    items: items ?? this.items,
    cargando: cargando ?? this.cargando,
    hayMas: hayMas ?? this.hayMas,
    error: error,
  );
}

final listadoComprobantesProvider =
    NotifierProvider.autoDispose<
      ListadoComprobantesController,
      ListadoComprobantes
    >(ListadoComprobantesController.new);

class ListadoComprobantesController extends Notifier<ListadoComprobantes> {
  int _generacion = 0;
  bool _primeraSincronizacion = true;

  @override
  ListadoComprobantes build() {
    final repositorio = ref.watch(comprobantesRepositoryProvider);
    final suscripcion = repositorio.cambios().listen(_aplicarCambio);
    ref.onDispose(suscripcion.cancel);
    Future.microtask(recargar);
    return const ListadoComprobantes(cargando: true);
  }

  void _aplicarCambio(CambioFila cambio) {
    if (cambio.esSincronizacion) {
      if (_primeraSincronizacion) {
        _primeraSincronizacion = false;
      } else {
        unawaited(recargar());
      }
      return;
    }
    if (cambio.evento == PostgresChangeEvent.delete) return;
    final recibido = Comprobante.desdeFila(cambio.fila);
    final coincide = state.filtros.coincide(recibido);
    final indice = state.items.indexWhere((c) => c.id == recibido.id);
    final items = [...state.items];
    if (indice >= 0) {
      if (coincide) {
        items[indice] = recibido;
      } else {
        items.removeAt(indice);
      }
    } else if (coincide && cambio.evento == PostgresChangeEvent.insert) {
      items.insert(0, recibido);
    } else {
      return;
    }
    state = state.copiar(items: items, error: state.error);
  }

  Future<void> aplicarFiltros(FiltrosComprobantes filtros) async {
    state = state.copiar(filtros: filtros);
    await recargar();
  }

  Future<void> recargar() async {
    final generacion = ++_generacion;
    state = state.copiar(cargando: true);
    await _traer(generacion, 0, const []);
  }

  Future<void> cargarMas() async {
    if (state.cargando || !state.hayMas) return;
    final generacion = ++_generacion;
    state = state.copiar(cargando: true);
    await _traer(generacion, state.items.length, state.items);
  }

  Future<void> _traer(
    int generacion,
    int desplazamiento,
    List<Comprobante> previos,
  ) async {
    try {
      final pagina = await ref
          .read(comprobantesRepositoryProvider)
          .listar(state.filtros, desplazamiento: desplazamiento);
      if (!ref.mounted || generacion != _generacion) return;
      final conocidos = previos.map((c) => c.id).toSet();
      state = state.copiar(
        items: [...previos, ...pagina.where((c) => !conocidos.contains(c.id))],
        cargando: false,
        hayMas: pagina.length == tamanoPaginaComprobantes,
      );
    } catch (error) {
      if (!ref.mounted || generacion != _generacion) return;
      state = state.copiar(cargando: false, error: error);
    }
  }
}
