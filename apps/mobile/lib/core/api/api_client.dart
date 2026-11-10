import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../env/env.dart';
import '../errores/errores.dart';

export '../errores/errores.dart' show ApiException, mensajeDeError;

final apiClientProvider = Provider<ApiClient>((ref) {
  final cliente = ApiClient(Supabase.instance.client.auth);
  ref.onDispose(cliente.cerrar);
  return cliente;
});

class ApiClient {
  ApiClient(this._auth, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 45),
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _adjuntarToken, onError: _reintentarSi401),
    );
  }

  static const _yaReintentado = 'ya_reintentado';

  final GoTrueClient _auth;
  final Dio _dio;
  Future<String?>? _renovacionEnCurso;

  void cerrar() => _dio.close();

  Future<T> get<T>(
    String ruta, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _enviar<T>('GET', ruta, query: query, headers: headers);

  Future<T> post<T>(
    String ruta, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? esperaRespuesta,
  }) => _enviar<T>(
    'POST',
    ruta,
    data: data,
    query: query,
    headers: headers,
    esperaRespuesta: esperaRespuesta,
  );

  Future<T> put<T>(
    String ruta, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _enviar<T>('PUT', ruta, data: data, query: query, headers: headers);

  Future<T> patch<T>(
    String ruta, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _enviar<T>('PATCH', ruta, data: data, query: query, headers: headers);

  Future<T> delete<T>(
    String ruta, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _enviar<T>('DELETE', ruta, data: data, query: query, headers: headers);

  Future<Uint8List> postBytes(
    String ruta, {
    Object? data,
    Map<String, dynamic>? query,
    Duration? esperaRespuesta,
  }) async {
    final bytes = await _enviar<List<int>>(
      'POST',
      ruta,
      data: data,
      query: query,
      esperaRespuesta: esperaRespuesta,
      tipoRespuesta: ResponseType.bytes,
    );
    return Uint8List.fromList(bytes);
  }

  Future<T> _enviar<T>(
    String metodo,
    String ruta, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? esperaRespuesta,
    ResponseType? tipoRespuesta,
  }) async {
    try {
      final respuesta = await _dio.request<dynamic>(
        ruta,
        data: data,
        queryParameters: query,
        options: Options(
          method: metodo,
          headers: headers,
          receiveTimeout: esperaRespuesta,
          responseType: tipoRespuesta,
        ),
      );
      return respuesta.data as T;
    } on DioException catch (error) {
      throw _mapearError(error);
    }
  }

  Future<void> _adjuntarToken(
    RequestOptions opciones,
    RequestInterceptorHandler handler,
  ) async {
    var sesion = _auth.currentSession;
    if (sesion != null && sesion.isExpired) {
      await _renovarToken();
      sesion = _auth.currentSession;
    }
    if (sesion != null) {
      opciones.headers['Authorization'] = 'Bearer ${sesion.accessToken}';
    }
    handler.next(opciones);
  }

  Future<void> _reintentarSi401(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final opciones = error.requestOptions;
    final debeReintentar =
        error.response?.statusCode == 401 &&
        opciones.extra[_yaReintentado] != true &&
        _auth.currentSession != null;
    if (!debeReintentar) {
      handler.next(error);
      return;
    }
    final token = await _renovarToken();
    if (token == null) {
      handler.next(error);
      return;
    }
    opciones.extra[_yaReintentado] = true;
    opciones.headers['Authorization'] = 'Bearer $token';
    final cuerpo = opciones.data;
    if (cuerpo is FormData) opciones.data = cuerpo.clone();
    try {
      handler.resolve(await _dio.fetch<dynamic>(opciones));
    } on DioException catch (errorReintento) {
      handler.next(errorReintento);
    }
  }

  Future<String?> _renovarToken() {
    return _renovacionEnCurso ??= _ejecutarRenovacion().whenComplete(() {
      _renovacionEnCurso = null;
    });
  }

  Future<String?> _ejecutarRenovacion() async {
    try {
      final respuesta = await _auth.refreshSession();
      return respuesta.session?.accessToken;
    } on AuthRetryableFetchException {
      return null;
    } on AuthException {
      await _auth.signOut(scope: SignOutScope.local);
      return null;
    }
  }

  ApiException _mapearError(DioException error) {
    final interno = error.error;
    if (interno is ApiException) return interno;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          'TIEMPO_AGOTADO',
          'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'SIN_CONEXION',
          'No hay conexión con el servidor. Revisa tu internet.',
        );
      case DioExceptionType.cancel:
        return const ApiException('CANCELADO', 'La operación se canceló.');
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return _mapearRespuesta(error.response);
    }
  }

  ApiException _mapearRespuesta(Response<dynamic>? respuesta) {
    final status = respuesta?.statusCode;
    final cuerpo = _cuerpoLegible(respuesta?.data);
    if (cuerpo is Map && cuerpo['error'] is Map) {
      final detalle = cuerpo['error'] as Map;
      return ApiException(
        detalle['codigo']?.toString() ?? 'ERROR',
        detalle['mensaje']?.toString() ?? _mensajePorEstado(status),
        status: status,
        detalles: detalle['detalles'],
      );
    }
    return ApiException(
      status == 401 ? 'NO_AUTORIZADO' : 'ERROR',
      _mensajePorEstado(status),
      status: status,
    );
  }

  Object? _cuerpoLegible(Object? cuerpo) {
    if (cuerpo is! List<int>) return cuerpo;
    try {
      return jsonDecode(utf8.decode(cuerpo));
    } on FormatException {
      return null;
    }
  }

  String _mensajePorEstado(int? status) => switch (status) {
    401 => 'Tu sesión venció. Vuelve a iniciar sesión.',
    403 => 'No tienes permiso para realizar esta acción.',
    404 => 'No se encontró lo que buscabas.',
    final s? when s >= 500 =>
      'El servidor tuvo un problema. Inténtalo en unos minutos.',
    _ => 'No se pudo completar la operación. Inténtalo de nuevo.',
  };
}
