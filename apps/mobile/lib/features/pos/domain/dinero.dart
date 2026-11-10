import 'package:decimal/decimal.dart';

final Decimal cero = Decimal.zero;
final Decimal cien = Decimal.fromInt(100);

Decimal redondear2(Decimal valor) => valor.round(scale: 2);

Decimal dividir(Decimal a, Decimal b) =>
    (a / b).toDecimal(scaleOnInfinitePrecision: 10);

Decimal decimalDe(Object? valor) {
  if (valor == null) return cero;
  if (valor is Decimal) return valor;
  return Decimal.tryParse(valor.toString().trim()) ?? cero;
}

Decimal? decimalDeEntrada(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  if (limpio.isEmpty) return null;
  return Decimal.tryParse(limpio);
}

String importe(Decimal valor) => redondear2(valor).toStringAsFixed(2);

String soles(Decimal valor) => 'S/ ${importe(valor)}';

String cantidadLegible(Decimal valor) {
  final texto = valor.toStringAsFixed(4);
  return texto.replaceFirst(RegExp(r'\.?0+$'), '');
}
