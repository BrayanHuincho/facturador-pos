import 'package:shared_preferences/shared_preferences.dart';

import '../domain/impresora.dart';

class ConfigImpresoraStore {
  static const _conexion = 'impresora.conexion';
  static const _papel = 'impresora.papel';
  static const _nombre = 'impresora.nombre';
  static const _direccion = 'impresora.direccion';
  static const _ip = 'impresora.ip';
  static const _puerto = 'impresora.puerto';
  static const _alEmitir = 'impresora.al_emitir';

  Future<ConfigImpresora> leer() async {
    final p = await SharedPreferences.getInstance();
    return ConfigImpresora(
      conexion:
          ConexionImpresora.values.asNameMap()[p.getString(_conexion)] ??
          ConexionImpresora.bluetooth,
      papel:
          PapelImpresora.values.asNameMap()[p.getString(_papel)] ??
          PapelImpresora.mm80,
      nombreBluetooth: p.getString(_nombre),
      direccionBluetooth: p.getString(_direccion),
      ip: p.getString(_ip) ?? '',
      puerto: p.getInt(_puerto) ?? ConfigImpresora.puertoPorDefecto,
      imprimirAlEmitir: p.getBool(_alEmitir) ?? false,
    );
  }

  Future<void> guardar(ConfigImpresora c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_conexion, c.conexion.name);
    await p.setString(_papel, c.papel.name);
    if (c.direccionBluetooth != null) {
      await p.setString(_direccion, c.direccionBluetooth!);
      await p.setString(_nombre, c.nombreBluetooth ?? c.direccionBluetooth!);
    }
    await p.setString(_ip, c.ip);
    await p.setInt(_puerto, c.puerto);
    await p.setBool(_alEmitir, c.imprimirAlEmitir);
  }
}
