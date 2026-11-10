import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const duracionSesionRecordada = Duration(days: 7);

bool sesionVencida(DateTime inicio, DateTime ahora) =>
    ahora.difference(inicio) >= duracionSesionRecordada;

class AlmacenSesionSegura extends LocalStorage {
  AlmacenSesionSegura({
    this._almacen = const FlutterSecureStorage(),
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  static final instancia = AlmacenSesionSegura();

  static const _clave = 'supabase.sesion';
  static const _claveInicio = 'supabase.sesion.inicio';
  static const _claveCorreo = 'sesion.correo_recordado';

  final FlutterSecureStorage _almacen;
  final DateTime Function() _reloj;
  bool _recordar = true;
  String? _memoria;

  @override
  Future<void> initialize() async {
    final persistida = await _almacen.read(key: _clave);
    if (persistida == null) {
      await _almacen.delete(key: _claveInicio);
      return;
    }
    final inicio = await _leerInicio();
    if (inicio == null) {
      await _registrarInstante();
      return;
    }
    if (sesionVencida(inicio, _reloj())) {
      await _almacen.delete(key: _clave);
      await _almacen.delete(key: _claveInicio);
    }
  }

  Future<DateTime?> _leerInicio() async {
    final valor = await _almacen.read(key: _claveInicio);
    return valor == null ? null : DateTime.tryParse(valor);
  }

  Future<void> _registrarInstante() => _almacen.write(
    key: _claveInicio,
    value: _reloj().toUtc().toIso8601String(),
  );

  Future<void> prepararInicio({required bool recordar}) async {
    _recordar = recordar;
    _memoria = null;
    if (!recordar) await _almacen.delete(key: _clave);
  }

  Future<void> registrarInicio({
    required bool recordar,
    required String correo,
  }) async {
    await _registrarInstante();
    if (recordar) {
      await _almacen.write(key: _claveCorreo, value: correo);
    } else {
      await _almacen.delete(key: _claveCorreo);
    }
  }

  Future<String?> correoRecordado() => _almacen.read(key: _claveCorreo);

  Future<bool> sesionPasoElPlazo() async {
    final inicio = await _leerInicio();
    return inicio != null && sesionVencida(inicio, _reloj());
  }

  @override
  Future<bool> hasAccessToken() async =>
      _memoria != null || await _almacen.containsKey(key: _clave);

  @override
  Future<String?> accessToken() async =>
      _memoria ?? await _almacen.read(key: _clave);

  @override
  Future<void> persistSession(String persistSessionString) async {
    if (_recordar) {
      await _almacen.write(key: _clave, value: persistSessionString);
      return;
    }
    _memoria = persistSessionString;
    await _almacen.delete(key: _clave);
  }

  @override
  Future<void> removePersistedSession() async {
    _memoria = null;
    await _almacen.delete(key: _clave);
    await _almacen.delete(key: _claveInicio);
  }
}
