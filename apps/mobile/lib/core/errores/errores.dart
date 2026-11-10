import 'package:supabase_flutter/supabase_flutter.dart';

class ApiException implements Exception {
  const ApiException(this.codigo, this.mensaje, {this.status, this.detalles});

  final String codigo;
  final String mensaje;
  final int? status;
  final Object? detalles;

  @override
  String toString() => 'ApiException($codigo): $mensaje';
}

String mensajeDeError(Object error) {
  if (error is ApiException) return error.mensaje;
  if (error is AuthException) return _mensajeAuth(error);
  if (error is PostgrestException) {
    return 'No se pudo leer la información. Inténtalo de nuevo.';
  }
  return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
}

String _mensajeAuth(AuthException error) {
  if (error is AuthRetryableFetchException) {
    return 'No hay conexión con el servidor. Revisa tu internet.';
  }
  final mensaje = error.message.toLowerCase();
  if (mensaje.contains('invalid login')) {
    return 'El correo o la contraseña no son correctos.';
  }
  if (mensaje.contains('expired') || mensaje.contains('invalid')) {
    return 'El código no es válido o ya venció. Solicita uno nuevo.';
  }
  if (mensaje.contains('rate limit') || error.statusCode == '429') {
    return 'Demasiados intentos. Espera unos minutos.';
  }
  if (mensaje.contains('password')) {
    return 'Elige una contraseña más segura, de al menos 8 caracteres.';
  }
  return 'No se pudo completar la autenticación. Inténtalo de nuevo.';
}
