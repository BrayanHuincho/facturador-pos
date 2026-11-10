import 'dart:typed_data';

import 'package:decimal/decimal.dart';

import 'escpos.dart';
import 'impresora.dart';

Decimal _decimal(Object? valor) =>
    Decimal.tryParse('${valor ?? ''}'.trim()) ?? Decimal.zero;

String _monto(Object? valor) =>
    _decimal(valor).round(scale: 2).toStringAsFixed(2);

String _cantidad(Object? valor) =>
    _decimal(valor).toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');

const _nombresDocumento = {
  '01': 'FACTURA ELECTRONICA',
  '03': 'BOLETA DE VENTA ELECTRONICA',
  'NV': 'NOTA DE VENTA',
};

Uint8List construirTicket({
  required Map<String, dynamic> comprobante,
  required Map<String, dynamic> empresa,
  required PapelImpresora papel,
}) {
  final doc = DocumentoEscPos(papel);
  final nombre =
      '${empresa['nombre_comercial'] ?? empresa['razon_social'] ?? ''}';
  if (nombre.isNotEmpty) doc.centrado(nombre, negrita: true);
  if (empresa['ruc'] != null) doc.centrado('RUC ${empresa['ruc']}');
  if (empresa['direccion'] != null) doc.centrado('${empresa['direccion']}');
  doc.separador();

  final tipo = '${comprobante['tipo'] ?? ''}';
  doc.centrado(_nombresDocumento[tipo] ?? 'COMPROBANTE', negrita: true);
  final correlativo = '${comprobante['correlativo'] ?? ''}'.padLeft(8, '0');
  doc.centrado('${comprobante['serie'] ?? ''}-$correlativo', negrita: true);
  doc.texto(
    'Fecha: ${comprobante['fecha_emision'] ?? ''} ${comprobante['hora_emision'] ?? ''}'
        .trim(),
  );
  doc.texto('Cliente: ${comprobante['cliente_nombre'] ?? ''}');
  final documentoCliente = '${comprobante['cliente_numero_documento'] ?? ''}';
  if (documentoCliente.isNotEmpty) doc.texto('Doc: $documentoCliente');
  doc.separador();

  final items = comprobante['items'] ?? comprobante['comprobante_items'];
  for (final item in (items as List<dynamic>? ?? const [])) {
    final linea = Map<String, dynamic>.from(item as Map);
    doc.texto('${linea['descripcion'] ?? ''}');
    doc.columnasExtremos(
      '${_cantidad(linea['cantidad'])} x ${_monto(linea['precio_unitario'])}',
      _monto(linea['total']),
    );
    if (_decimal(linea['descuento']) > Decimal.zero) {
      doc.columnasExtremos('  Descuento', '-${_monto(linea['descuento'])}');
    }
  }
  doc.separador();

  void fila(String etiqueta, Object? valor) {
    if (_decimal(valor) > Decimal.zero) {
      doc.columnasExtremos(etiqueta, _monto(valor));
    }
  }

  fila('Op. gravadas', comprobante['op_gravadas']);
  fila('Op. exoneradas', comprobante['op_exoneradas']);
  fila('Op. inafectas', comprobante['op_inafectas']);
  fila('Descuento', comprobante['descuento_total']);
  fila('IGV', comprobante['igv']);
  fila('ICBPER', comprobante['icbper']);
  doc.columnasExtremos('TOTAL S/', _monto(comprobante['total']), negrita: true);
  fila('Recibido', comprobante['recibido']);
  fila('Vuelto', comprobante['vuelto']);

  final qr = comprobante['qr'];
  if (tipo != 'NV' && qr is String && qr.isNotEmpty) {
    doc.separador();
    doc.qr(qr);
  }
  final hash = comprobante['hash'];
  if (hash is String && hash.isNotEmpty) doc.centrado(hash);
  doc.centrado('Gracias por su compra');
  return doc.terminar();
}

Uint8List construirPaginaPrueba(PapelImpresora papel) {
  final doc = DocumentoEscPos(papel);
  doc.centrado('PRUEBA DE IMPRESION', negrita: true);
  doc.separador();
  doc.texto('Papel: ${papel.etiqueta}');
  doc.texto('Acentos: áéíóú ñ Ñ');
  doc.columnasExtremos('Total', 'S/ 0.00', negrita: true);
  doc.qr('Facturador POS');
  return doc.terminar();
}
