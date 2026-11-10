import 'package:decimal/decimal.dart';
import 'package:facturador_pos/core/formatos/formatos.dart';

export 'package:facturador_pos/core/formatos/formatos.dart'
    show formatearNumero, formatearCantidad;

Decimal decimalDe(Object? valor) => parseDecimal(valor);

Decimal? decimalOpcional(Object? valor) {
  if (valor == null) return null;
  return Decimal.tryParse(valor.toString());
}

Decimal? decimalDeEntrada(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(limpio)) return null;
  return Decimal.tryParse(limpio);
}

String? validarMonto(String? texto, {bool permitirCero = false}) {
  final monto = decimalDeEntrada(texto ?? '');
  if (monto == null) return 'Ingresa un monto válido';
  if (monto.scale > 2) return 'Máximo 2 decimales';
  if (!permitirCero && monto == Decimal.zero) return 'Debe ser mayor a cero';
  return null;
}

String formatearMoneda(Decimal valor, {String moneda = 'PEN'}) =>
    formatearDinero(valor, moneda: moneda);
