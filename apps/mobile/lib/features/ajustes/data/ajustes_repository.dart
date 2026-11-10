import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

import '../../../core/api/api_client.dart';
import '../../../core/sesion/sesion_providers.dart' hide Empresa;
import '../domain/ajustes_models.dart';

const String bucketImagenes = 'imagenes';

final ajustesRepositoryProvider = Provider<AjustesRepository>(
  (ref) => AjustesRepository(
    ref.watch(apiClientProvider),
    ref.watch(supabaseProvider),
  ),
);

final estadoSunatProvider = FutureProvider.autoDispose<EstadoSunat>(
  (ref) => ref.watch(ajustesRepositoryProvider).obtenerEstadoSunat(),
);

final datosEmpresaProvider = FutureProvider.autoDispose<DatosEmpresa>(
  (ref) => ref.watch(ajustesRepositoryProvider).obtenerEmpresa(),
);

final seriesProvider = FutureProvider.autoDispose<List<SerieComprobante>>(
  (ref) => ref.watch(ajustesRepositoryProvider).listarSeries(),
);

final establecimientosProvider =
    FutureProvider.autoDispose<List<Establecimiento>>(
      (ref) => ref.watch(ajustesRepositoryProvider).listarEstablecimientos(),
    );

final usuariosProvider = FutureProvider.autoDispose<List<UsuarioSistema>>(
  (ref) => ref.watch(ajustesRepositoryProvider).listarUsuarios(),
);

String tipoContenidoImagen(String nombreArchivo) {
  final nombre = nombreArchivo.toLowerCase();
  if (nombre.endsWith('.png')) return 'image/png';
  if (nombre.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

class AjustesRepository {
  AjustesRepository(this._api, this._supabase);

  final ApiClient _api;
  final SupabaseClient _supabase;

  Future<EstadoSunat> obtenerEstadoSunat() async => EstadoSunat.desdeJson(
    await _api.get<Map<String, dynamic>>('/sunat/configuracion'),
  );

  Future<void> guardarCredencialesSunat({
    required String usuarioSol,
    required String? claveSol,
    required String envioBoletas,
    String? greClientId,
    String? greClientSecret,
  }) => _api.put<Map<String, dynamic>>(
    '/sunat/credenciales',
    data: {
      'usuario_sol': usuarioSol,
      'clave_sol': ?claveSol,
      'gre_client_id': ?greClientId,
      'gre_client_secret': ?greClientSecret,
      'envio_boletas': envioBoletas,
    },
  );

  Future<void> subirCertificado({
    required Uint8List contenido,
    required String nombreArchivo,
    required String clave,
  }) => _api.post<Map<String, dynamic>>(
    '/sunat/certificado',
    data: FormData.fromMap({
      'clave': clave,
      'archivo': MultipartFile.fromBytes(contenido, filename: nombreArchivo),
    }),
  );

  Future<void> actualizarNombrePerfil(String nombre) =>
      _api.patch<Map<String, dynamic>>('/perfil', data: {'nombre': nombre});

  Future<void> subirFotoPerfil({
    required Uint8List contenido,
    required String nombreArchivo,
  }) => _api.post<Map<String, dynamic>>(
    '/perfil/foto',
    data: FormData.fromMap({
      'archivo': MultipartFile.fromBytes(contenido, filename: nombreArchivo),
    }),
  );

  Future<void> quitarFotoPerfil() =>
      _api.delete<Map<String, dynamic>>('/perfil/foto');

  Future<void> eliminarCertificado() =>
      _api.delete<Map<String, dynamic>>('/sunat/certificado');

  Future<void> cambiarEntorno({
    required String entorno,
    String? confirmarRuc,
  }) => _api.put<Map<String, dynamic>>(
    '/sunat/entorno',
    data: {'entorno': entorno, 'confirmar_ruc': ?confirmarRuc},
  );

  Future<ResultadoPruebaSunat> probarConexion() async =>
      ResultadoPruebaSunat.desdeJson(
        await _api.post<Map<String, dynamic>>(
          '/sunat/probar',
          esperaRespuesta: const Duration(seconds: 90),
        ),
      );

  Future<DatosEmpresa> obtenerEmpresa() async =>
      DatosEmpresa.desdeJson(await _api.get<Map<String, dynamic>>('/empresa'));

  Future<void> guardarEmpresa(Map<String, dynamic> datos) =>
      _api.put<Map<String, dynamic>>('/empresa', data: datos);

  Future<String> subirLogo({
    required Uint8List contenido,
    required String nombreArchivo,
  }) async {
    final extension = nombreArchivo.contains('.')
        ? nombreArchivo.split('.').last.toLowerCase()
        : 'jpg';
    final ruta =
        'logo/logo-${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _supabase.storage
        .from(bucketImagenes)
        .uploadBinary(
          ruta,
          contenido,
          fileOptions: FileOptions(
            contentType: tipoContenidoImagen(nombreArchivo),
            upsert: true,
          ),
        );
    return ruta;
  }

  String urlPublicaImagen(String ruta) =>
      _supabase.storage.from(bucketImagenes).getPublicUrl(ruta);

  Future<List<SerieComprobante>> listarSeries() async {
    final filas = await _api.get<List<dynamic>>('/series');
    return filas
        .cast<Map<String, dynamic>>()
        .map(SerieComprobante.desdeJson)
        .toList();
  }

  Future<void> crearSerie({
    required String establecimientoId,
    required String tipo,
    required String serie,
    required int ultimo,
  }) => _api.post<Map<String, dynamic>>(
    '/series',
    data: {
      'establecimiento_id': establecimientoId,
      'tipo': tipo,
      'serie': serie,
      'ultimo': ultimo,
      'activa': true,
    },
  );

  Future<void> actualizarSerie(String id, Map<String, dynamic> cambios) =>
      _api.patch<Map<String, dynamic>>('/series/$id', data: cambios);

  Future<List<Establecimiento>> listarEstablecimientos() async {
    final filas = await _supabase
        .from('establecimientos')
        .select('id, codigo, nombre')
        .eq('activo', true)
        .order('codigo');
    return filas.map(Establecimiento.desdeJson).toList();
  }

  Future<void> actualizarEstablecimiento(
    String id,
    Map<String, dynamic> cambios,
  ) => _api.patch<Map<String, dynamic>>('/establecimientos/$id', data: cambios);

  Future<List<UsuarioSistema>> listarUsuarios() async {
    final filas = await _api.get<List<dynamic>>('/usuarios');
    return filas
        .cast<Map<String, dynamic>>()
        .map(UsuarioSistema.desdeJson)
        .toList();
  }

  Future<void> crearUsuario({
    required String nombre,
    required String correo,
    required String clave,
    required String rol,
    required String? establecimientoId,
  }) => _api.post<Map<String, dynamic>>(
    '/usuarios',
    data: {
      'nombre': nombre,
      'correo': correo,
      'clave': clave,
      'rol': rol,
      'establecimiento_id': ?establecimientoId,
    },
  );

  Future<void> actualizarUsuario(String id, Map<String, dynamic> cambios) =>
      _api.patch<Map<String, dynamic>>('/usuarios/$id', data: cambios);
}
