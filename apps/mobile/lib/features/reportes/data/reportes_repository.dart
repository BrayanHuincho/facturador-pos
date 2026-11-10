import 'package:facturador_pos/core/api/api_client.dart';
import 'package:facturador_pos/features/comprobantes/data/comprobantes_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/reporte.dart';

final reportesRepositoryProvider = Provider<ReportesRepository>(
  (ref) => ReportesRepository(ref.watch(apiClientProvider)),
);

class ReportesRepository {
  ReportesRepository(this._api);

  final ApiClient _api;

  Future<KpisReporte> resumen(String desde, String hasta) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/reportes/resumen?desde=$desde&hasta=$hasta',
    );
    return KpisReporte.desdeJson(json);
  }

  Future<List<FilaVenta>> ventas(
    String desde,
    String hasta,
    Agrupacion agrupacion,
  ) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/reportes/ventas?desde=$desde&hasta=$hasta&agrupar=${agrupacion.codigo}',
    );
    return filasDeRespuesta(json).map(FilaVenta.desdeJson).toList();
  }

  Future<String> exportarCsv(String desde, String hasta) async {
    final respuesta = await _api.get<dynamic>(
      '/reportes/exportar?desde=$desde&hasta=$hasta',
    );
    return respuesta.toString();
  }
}
