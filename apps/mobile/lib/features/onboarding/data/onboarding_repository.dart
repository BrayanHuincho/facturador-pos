import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(apiClientProvider)),
);

class DatosRuc {
  const DatosRuc({
    required this.razonSocial,
    required this.direccion,
    required this.ubigeo,
    required this.departamento,
    required this.provincia,
    required this.distrito,
  });

  factory DatosRuc.desdeJson(Map<String, dynamic> json) {
    String texto(List<String> claves) {
      for (final clave in claves) {
        final valor = json[clave]?.toString().trim();
        if (valor != null && valor.isNotEmpty) return valor;
      }
      return '';
    }

    return DatosRuc(
      razonSocial: texto(['razon_social', 'nombre']),
      direccion: texto(['direccion']),
      ubigeo: texto(['ubigeo']),
      departamento: texto(['departamento']),
      provincia: texto(['provincia']),
      distrito: texto(['distrito']),
    );
  }

  final String razonSocial;
  final String direccion;
  final String ubigeo;
  final String departamento;
  final String provincia;
  final String distrito;
}

const empresaDePruebaInicial = <String, dynamic>{
  'ruc': '20000000001',
  'razon_social': 'EMPRESA DE PRUEBA',
  'nombre_comercial': 'Mi negocio de prueba',
  'ubigeo': '150101',
  'departamento': 'LIMA',
  'provincia': 'LIMA',
  'distrito': 'LIMA',
  'direccion': 'AV PRUEBA 123',
};

const establecimientoDePruebaInicial = <String, dynamic>{
  'codigo': '0000',
  'nombre': 'Principal',
  'direccion': 'AV PRUEBA 123',
  'ubigeo': '150101',
};

class OnboardingRepository {
  const OnboardingRepository(this._api);

  final ApiClient _api;

  Future<DatosRuc> consultarRuc(String ruc) async {
    final respuesta = await _api.get<Map<String, dynamic>>(
      '/consultas/documento/6/$ruc',
    );
    return DatosRuc.desdeJson(respuesta);
  }

  Future<void> guardarConfiguracionInicial({
    required Map<String, dynamic> empresa,
    required Map<String, dynamic> establecimiento,
  }) => _api.post<dynamic>(
    '/configuracion/inicial',
    data: {'empresa': empresa, 'establecimiento': establecimiento},
  );

  Future<void> actualizarEmpresa(Map<String, dynamic> empresa) =>
      _api.put<dynamic>('/empresa', data: empresa);

  Future<void> guardarCredenciales({
    required String usuarioSol,
    required String claveSol,
    required String envioBoletas,
  }) => _api.put<dynamic>(
    '/sunat/credenciales',
    data: {
      'usuario_sol': usuarioSol,
      'clave_sol': claveSol,
      'envio_boletas': envioBoletas,
    },
  );

  Future<void> subirCertificado({
    required Uint8List bytes,
    required String nombreArchivo,
    required String clave,
  }) => _api.post<dynamic>(
    '/sunat/certificado',
    data: FormData.fromMap({
      'archivo': MultipartFile.fromBytes(bytes, filename: nombreArchivo),
      'clave': clave,
    }),
  );

  Future<void> definirEntorno({
    required String entorno,
    required String confirmarRuc,
  }) => _api.put<dynamic>(
    '/sunat/entorno',
    data: {'entorno': entorno, 'confirmar_ruc': confirmarRuc},
  );
}
