import 'package:facturador_pos/core/api/api_client.dart';
import 'package:facturador_pos/core/sesion/sesion_providers.dart';
import 'package:facturador_pos/features/comprobantes/data/cambios_tabla.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/guia.dart';

const int tamanoPaginaGuias = 25;

final guiasRepositoryProvider = Provider<GuiasRepository>(
  (ref) => GuiasRepository(
    ref.watch(supabaseProvider),
    ref.watch(apiClientProvider),
  ),
);

final guiaDetalleProvider = StreamProvider.autoDispose.family<Guia, String>(
  (ref, id) => ref.watch(guiasRepositoryProvider).observar(id),
);

final seriesGuiaProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final perfil = await ref.watch(perfilActualProvider.future);
  return ref
      .watch(guiasRepositoryProvider)
      .seriesActivas(perfil?.establecimientoId);
});

class GuiasRepository {
  GuiasRepository(this._cliente, this._api);

  final SupabaseClient _cliente;
  final ApiClient _api;

  Future<List<Guia>> listar({
    required int desplazamiento,
    String? estado,
  }) async {
    var consulta = _cliente.from('guias_remision').select();
    if (estado != null) consulta = consulta.eq('estado', estado);
    final filas = await consulta
        .order('creado_en')
        .range(desplazamiento, desplazamiento + tamanoPaginaGuias - 1);
    return filas.map(Guia.desdeFila).toList();
  }

  Future<Guia> obtener(String id) async {
    final fila = await _cliente
        .from('guias_remision')
        .select('*, guia_items(*)')
        .eq('id', id)
        .single();
    return Guia.desdeFila(fila);
  }

  Stream<CambioFila> cambios() => observarTabla(_cliente, 'guias_remision');

  Stream<Guia> observar(String id) async* {
    yield await obtener(id);
    await for (final _ in observarTabla(_cliente, 'guias_remision', id: id)) {
      Guia? actualizada;
      try {
        actualizada = await obtener(id);
      } on PostgrestException {
        actualizada = null;
      }
      if (actualizada != null) yield actualizada;
    }
  }

  Future<List<String>> seriesActivas(String? establecimientoId) async {
    var consulta = _cliente
        .from('series')
        .select('serie')
        .eq('tipo', '09')
        .eq('activa', true);
    if (establecimientoId != null) {
      consulta = consulta.eq('establecimiento_id', establecimientoId);
    }
    final filas = await consulta.order('serie', ascending: true);
    return filas.map((fila) => fila['serie'] as String).toList();
  }

  Future<String> emitir(Map<String, dynamic> guia) async {
    final respuesta = await _api.post<Map<String, dynamic>>(
      '/guias',
      data: guia,
    );
    final anidada = respuesta['guia'];
    final fila = anidada is Map<String, dynamic> ? anidada : respuesta;
    return fila['id'] as String;
  }

  Future<void> reenviar(String id) => _api.post<dynamic>('/guias/$id/reenviar');

  Future<String> urlArchivo(String id, String tipo) async {
    final respuesta = await _api.get<Map<String, dynamic>>(
      '/guias/$id/archivo/$tipo',
    );
    return respuesta['url'] as String;
  }
}
