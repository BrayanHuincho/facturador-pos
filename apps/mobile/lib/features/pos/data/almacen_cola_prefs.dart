import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cola_checkout.dart';

class AlmacenColaPrefs implements AlmacenCola {
  AlmacenColaPrefs(String usuarioId) : _clave = 'pos.cola.$usuarioId';

  final String _clave;

  @override
  Future<String?> leer() async =>
      (await SharedPreferences.getInstance()).getString(_clave);

  @override
  Future<void> escribir(String contenido) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, contenido);
  }
}
