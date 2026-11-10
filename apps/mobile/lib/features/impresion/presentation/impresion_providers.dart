import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/config_impresora_store.dart';
import '../data/impresoras.dart';
import '../domain/impresora.dart';
import '../domain/ticket.dart';

final configImpresoraStoreProvider = Provider((ref) => ConfigImpresoraStore());

final configImpresoraProvider =
    AsyncNotifierProvider<ConfigImpresoraNotifier, ConfigImpresora>(
      ConfigImpresoraNotifier.new,
    );

class ConfigImpresoraNotifier extends AsyncNotifier<ConfigImpresora> {
  @override
  Future<ConfigImpresora> build() =>
      ref.read(configImpresoraStoreProvider).leer();

  Future<void> guardar(ConfigImpresora config) async {
    state = AsyncData(config);
    await ref.read(configImpresoraStoreProvider).guardar(config);
  }
}

final impresionServiceProvider = Provider((ref) => ImpresionService(ref));

class ImpresionService {
  ImpresionService(this._ref);

  final Ref _ref;

  Future<ConfigImpresora> _config() =>
      _ref.read(configImpresoraProvider.future);

  Future<void> _enviar(ConfigImpresora config, Uint8List bytes) =>
      crearImpresora(config).enviar(bytes);

  Future<void> imprimirComprobante({
    required Map<String, dynamic> comprobante,
    required Map<String, dynamic> empresa,
  }) async {
    final config = await _config();
    await _enviar(
      config,
      construirTicket(
        comprobante: comprobante,
        empresa: empresa,
        papel: config.papel,
      ),
    );
  }

  Future<void> imprimirPrueba(ConfigImpresora config) =>
      _enviar(config, construirPaginaPrueba(config.papel));
}
