import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

const localeApp = 'es';

Decimal parseDecimal(Object? valor) {
  if (valor == null) return Decimal.zero;
  if (valor is Decimal) return valor;
  return Decimal.tryParse(valor.toString().trim()) ?? Decimal.zero;
}

String formatearNumero(Decimal valor, {int decimales = 2}) {
  final redondeado = valor.round(scale: decimales);
  final negativo = redondeado < Decimal.zero;
  final partes = redondeado.abs().toStringAsFixed(decimales).split('.');
  final entero = partes.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+$)'),
    (_) => ',',
  );
  final fraccion = partes.length > 1 ? '.${partes[1]}' : '';
  return '${negativo ? '-' : ''}$entero$fraccion';
}

String simboloMoneda(String moneda) => moneda == 'USD' ? 'US\$' : 'S/';

String formatearDinero(Decimal importe, {String moneda = 'PEN'}) {
  final texto = formatearNumero(importe);
  final simbolo = simboloMoneda(moneda);
  return texto.startsWith('-')
      ? '-$simbolo ${texto.substring(1)}'
      : '$simbolo $texto';
}

String formatearSoles(Decimal importe) => formatearDinero(importe);

String formatearCantidad(Decimal cantidad) {
  final texto = formatearNumero(cantidad, decimales: 4);
  return texto.replaceFirst(RegExp(r'\.?0+$'), '');
}

String formatearFecha(DateTime fecha) =>
    DateFormat('dd/MM/yyyy', localeApp).format(fecha.toLocal());

String formatearHora(DateTime fecha) =>
    DateFormat('HH:mm', localeApp).format(fecha.toLocal());

String formatearFechaHora(DateTime fecha) =>
    '${formatearFecha(fecha)} ${formatearHora(fecha)}';

String formatearFechaLarga(DateTime fecha) =>
    DateFormat("d 'de' MMMM 'de' y", localeApp).format(fecha.toLocal());

String numeroComprobante(String serie, int correlativo) =>
    '$serie-${correlativo.toString().padLeft(8, '0')}';
