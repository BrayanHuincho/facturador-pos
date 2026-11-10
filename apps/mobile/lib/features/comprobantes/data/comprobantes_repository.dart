import 'package:facturador_pos/core/api/api_client.dart';
import 'package:facturador_pos/core/sesion/sesion_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/comprobante.dart';
import 'cambios_tabla.dart';

const int tamanoPaginaComprobantes = 25;

final comprobantesRepositoryProvider = Provider<ComprobantesRepository>(
  (ref) => ComprobantesRepository(
    ref.watch(supabaseProvider),
    ref.watch(apiClientProvider),
  ),
);

final comprobanteDetalleProvider = StreamProvider.autoDispose
    .family<Comprobante, String>(
      (ref, id) => ref.watch(comprobantesRepositoryProvider).observar(id),
    );

final resumenesProvider = FutureProvider.autoDispose<List<ProcesoSunat>>(
  (ref) =>
      ref.watch(comprobantesRepositoryProvider).listarProcesos('/resumenes'),
);

final bajasProvider = FutureProvider.autoDispose<List<ProcesoSunat>>(
  (ref) => ref.watch(comprobantesRepositoryProvider).listarProcesos('/bajas'),
);

String _terminoFiltro(String termino) {
  final limpio = termino.replaceAll('\\', '').replaceAll('"', '');
  return '"%$limpio%"';
}

List<Map<String, dynamic>> filasDeRespuesta(Object? respuesta) {
  final lista = respuesta is Map
      ? respuesta['items'] ?? respuesta['datos'] ?? respuesta['filas']
      : respuesta;
  if (lista is! List) return const [];
  return lista.cast<Map<String, dynamic>>();
}

class ComprobantesRepository {
  ComprobantesRepository(this._cliente, this._api);

  final SupabaseClient _cliente;
  final ApiClient _api;

  Future<List<Comprobante>> listar(
    FiltrosComprobantes filtros, {
    required int desplazamiento,
  }) async {
    var consulta = _cliente.from('comprobantes').select();
    if (filtros.tipo != null) consulta = consulta.eq('tipo', filtros.tipo!);
    if (filtros.estado != null) {
      consulta = consulta.eq('estado', filtros.estado!.codigo);
    }
    if (filtros.desde != null) {
      consulta = consulta.gte('fecha_emision', filtros.desde!);
    }
    if (filtros.hasta != null) {
      consulta = consulta.lte('fecha_emision', filtros.hasta!);
    }
    final termino = filtros.busqueda.trim();
    if (termino.isNotEmpty) {
      final numero = FiltrosComprobantes.patronNumero.firstMatch(termino);
      if (numero != null) {
        consulta = consulta
            .eq('serie', numero.group(1)!.toUpperCase())
            .eq('correlativo', int.parse(numero.group(2)!));
      } else {
        final patron = _terminoFiltro(termino);
        consulta = consulta.or(
          'cliente_nombre.ilike.$patron,'
          'cliente_numero_documento.ilike.$patron,'
          'serie.ilike.$patron',
        );
      }
    }
    final filas = await consulta
        .order('creado_en')
        .range(desplazamiento, desplazamiento + tamanoPaginaComprobantes - 1);
    return filas.map(Comprobante.desdeFila).toList();
  }

  Future<Comprobante> obtener(String id) async {
    final fila = await _cliente
        .from('comprobantes')
        .select('*, comprobante_items(*), pagos(*)')
        .eq('id', id)
        .single();
    return Comprobante.desdeFila(fila);
  }

  Future<Map<String, dynamic>> obtenerMapa(String id) =>
      _api.get<Map<String, dynamic>>('/comprobantes/$id');

  Stream<CambioFila> cambios() => observarTabla(_cliente, 'comprobantes');

  Stream<Comprobante> observar(String id) async* {
    yield await obtener(id);
    await for (final _ in observarTabla(_cliente, 'comprobantes', id: id)) {
      Comprobante? actualizado;
      try {
        actualizado = await obtener(id);
      } on PostgrestException {
        actualizado = null;
      }
      if (actualizado != null) yield actualizado;
    }
  }

  Future<void> reenviar(String id) =>
      _api.post<dynamic>('/comprobantes/$id/reenviar');

  Future<void> consultar(String id) =>
      _api.post<dynamic>('/comprobantes/$id/consultar');

  Future<void> anular(String id, String motivo) =>
      _api.post<dynamic>('/comprobantes/$id/anular', data: {'motivo': motivo});

  Future<void> emitirNota(
    String claveIdempotencia,
    Map<String, dynamic> nota,
  ) => _api.post<dynamic>(
    '/comprobantes/notas',
    data: nota,
    headers: {'Idempotency-Key': claveIdempotencia},
  );

  Future<String> urlArchivo(String id, String tipo) async {
    final respuesta = await _api.get<Map<String, dynamic>>(
      '/comprobantes/$id/archivo/$tipo',
    );
    return respuesta['url'] as String;
  }

  Future<List<ProcesoSunat>> listarProcesos(String ruta) async {
    final respuesta = await _api.get<dynamic>(ruta);
    return filasDeRespuesta(respuesta).map(ProcesoSunat.desdeFila).toList();
  }

  Future<void> consultarResumen(String id) =>
      _api.post<dynamic>('/resumenes/$id/consultar');
}
