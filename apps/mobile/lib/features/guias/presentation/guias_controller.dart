import 'dart:async';

import 'package:facturador_pos/features/comprobantes/data/cambios_tabla.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/guias_repository.dart';
import '../domain/guia.dart';

class ListadoGuias {
  const ListadoGuias({
    this.estado,
    this.items = const [],
    this.cargando = false,
    this.hayMas = true,
    this.error,
  });

  final String? estado;
  final List<Guia> items;
  final bool cargando;
  final bool hayMas;
  final Object? error;
}

final listadoGuiasProvider =
    NotifierProvider.autoDispose<ListadoGuiasController, ListadoGuias>(
      ListadoGuiasController.new,
    );

class ListadoGuiasController extends Notifier<ListadoGuias> {
  int _generacion = 0;
  bool _primeraSincronizacion = true;

  @override
  ListadoGuias build() {
    final suscripcion = ref
        .watch(guiasRepositoryProvider)
        .cambios()
        .listen(_aplicarCambio);
    ref.onDispose(suscripcion.cancel);
    Future.microtask(recargar);
    return const ListadoGuias(cargando: true);
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
    final recibida = Guia.desdeFila(cambio.fila);
    final coincide = state.estado == null || recibida.estado == state.estado;
    final indice = state.items.indexWhere((g) => g.id == recibida.id);
    final items = [...state.items];
    if (indice >= 0) {
      if (coincide) {
        items[indice] = recibida;
      } else {
        items.removeAt(indice);
      }
    } else if (coincide && cambio.evento == PostgresChangeEvent.insert) {
      items.insert(0, recibida);
    } else {
      return;
    }
    state = ListadoGuias(
      estado: state.estado,
      items: items,
      cargando: state.cargando,
      hayMas: state.hayMas,
      error: state.error,
    );
  }

  Future<void> filtrar(String? estado) async {
    state = ListadoGuias(estado: estado, items: state.items, cargando: true);
    await recargar();
  }

  Future<void> recargar() async {
    final generacion = ++_generacion;
    state = ListadoGuias(
      estado: state.estado,
      items: state.items,
      cargando: true,
    );
    await _traer(generacion, 0, const []);
  }

  Future<void> cargarMas() async {
    if (state.cargando || !state.hayMas) return;
    final generacion = ++_generacion;
    state = ListadoGuias(
      estado: state.estado,
      items: state.items,
      cargando: true,
    );
    await _traer(generacion, state.items.length, state.items);
  }

  Future<void> _traer(
    int generacion,
    int desplazamiento,
    List<Guia> previas,
  ) async {
    final estado = state.estado;
    try {
      final pagina = await ref
          .read(guiasRepositoryProvider)
          .listar(desplazamiento: desplazamiento, estado: estado);
      if (!ref.mounted || generacion != _generacion) return;
      final conocidas = previas.map((g) => g.id).toSet();
      state = ListadoGuias(
        estado: estado,
        items: [...previas, ...pagina.where((g) => !conocidas.contains(g.id))],
        hayMas: pagina.length == tamanoPaginaGuias,
      );
    } catch (error) {
      if (!ref.mounted || generacion != _generacion) return;
      state = ListadoGuias(
        estado: estado,
        items: state.items,
        hayMas: state.hayMas,
        error: error,
      );
    }
  }
}
