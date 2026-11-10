bool esRucValido(String ruc) {
  if (!RegExp(r'^(10|15|17|20)\d{9}$').hasMatch(ruc)) return false;
  const pesos = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  var suma = 0;
  for (var i = 0; i < pesos.length; i++) {
    suma += int.parse(ruc[i]) * pesos[i];
  }
  final digito = (11 - suma % 11) % 10;
  return digito == int.parse(ruc[10]);
}

String? validarRequerido(
  String? valor, {
  String mensaje = 'Completa este campo',
}) => (valor == null || valor.trim().isEmpty) ? mensaje : null;

String? validarRuc(String? valor) {
  final ruc = valor?.trim() ?? '';
  if (ruc.isEmpty) return 'Escribe el RUC';
  return esRucValido(ruc)
      ? null
      : 'Revisa el RUC: debe tener 11 dígitos válidos';
}

String? validarDni(String? valor) {
  final dni = valor?.trim() ?? '';
  return RegExp(r'^\d{8}$').hasMatch(dni)
      ? null
      : 'El DNI debe tener 8 dígitos';
}

String? validarCorreo(String? valor) {
  final correo = valor?.trim() ?? '';
  if (correo.isEmpty) return 'Escribe tu correo';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)
      ? null
      : 'Revisa el formato del correo';
}

String? validarCorreoOpcional(String? valor) =>
    (valor == null || valor.trim().isEmpty) ? null : validarCorreo(valor);

String? validarUbigeo(String? valor) {
  final ubigeo = valor?.trim() ?? '';
  return RegExp(r'^\d{6}$').hasMatch(ubigeo)
      ? null
      : 'El ubigeo debe tener 6 dígitos';
}

String? validarClaveNueva(String? valor) =>
    (valor ?? '').length < 8 ? 'Usa al menos 8 caracteres' : null;

String? celularPeru(String? texto) {
  final digitos = (texto ?? '').replaceAll(RegExp(r'\D'), '');
  final local = digitos.length == 11 && digitos.startsWith('51')
      ? digitos.substring(2)
      : digitos;
  return RegExp(r'^9\d{8}$').hasMatch(local) ? local : null;
}

String? errorDeCelular(String texto) {
  if (texto.isEmpty) return null;
  return celularPeru(texto) == null
      ? 'El celular tiene 9 dígitos y empieza con 9.'
      : null;
}
