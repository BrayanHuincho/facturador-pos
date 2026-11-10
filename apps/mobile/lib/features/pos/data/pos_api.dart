import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../domain/cobro.dart';
import '../domain/cola_checkout.dart';

bool esErrorTransitorio(ApiException error) {
  final status = error.status;
  if (status == null) return true;
  return status == 401 ||
      status == 408 ||
      status == 425 ||
      status == 429 ||
      status >= 500;
}

Exception clasificarError(ApiException error) => esErrorTransitorio(error)
    ? FalloTransitorio(error.mensaje)
    : FalloDefinitivo(error.mensaje, codigo: error.codigo);

class PosApi implements EmisorCheckout {
  PosApi(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> emitir(
    String claveIdempotencia,
    Map<String, dynamic> cuerpo,
  ) async {
    try {
      final respuesta = await _api.post<Map<String, dynamic>>(
        '/comprobantes',
        data: cuerpo,
        headers: {'Idempotency-Key': claveIdempotencia},
      );
      return respuesta;
    } on ApiException catch (e) {
      throw clasificarError(e);
    }
  }

  Future<Previsualizacion> previsualizar(Map<String, dynamic> cuerpo) async {
    try {
      final respuesta = await _api.post<Map<String, dynamic>>(
        '/comprobantes/previsualizar',
        data: cuerpo,
      );
      return Previsualizacion.fromJson(respuesta);
    } on ApiException catch (e) {
      throw clasificarError(e);
    }
  }

  Future<Uint8List> vistaPrevia(
    Map<String, dynamic> cuerpo, {
    String formato = 'ticket80',
  }) async {
    try {
      return await _api.postBytes(
        '/comprobantes/vista-previa',
        data: cuerpo,
        query: {'formato': formato},
      );
    } on ApiException catch (e) {
      throw clasificarError(e);
    }
  }

  Future<ClientePos?> consultarDocumento(String tipo, String numero) async {
    try {
      final datos = await _api.get<Map<String, dynamic>>(
        '/consultas/documento/$tipo/$numero',
      );
      return ClientePos(
        tipoDocumento: tipo,
        numeroDocumento: numero,
        nombre:
            datos['razon_social'] as String? ??
            datos['nombre'] as String? ??
            '',
        direccion: datos['direccion'] as String?,
      );
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<String> urlArchivo(String comprobanteId, String tipo) async {
    final datos = await _api.get<Map<String, dynamic>>(
      '/comprobantes/$comprobanteId/archivo/$tipo',
    );
    return datos['url'] as String;
  }
}
