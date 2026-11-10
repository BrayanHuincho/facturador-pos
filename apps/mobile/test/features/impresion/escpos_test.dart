import 'package:facturador_pos/features/impresion/domain/escpos.dart';
import 'package:facturador_pos/features/impresion/domain/impresora.dart';
import 'package:facturador_pos/features/impresion/domain/ticket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inicia y corta el papel', () {
    final bytes = DocumentoEscPos(PapelImpresora.mm58).terminar();
    expect(bytes.sublist(0, 2), [0x1B, 0x40]);
    expect(bytes.sublist(bytes.length - 3), [0x1D, 0x56, 0x01]);
  });

  test('alinea a los extremos segun el ancho del papel', () {
    for (final papel in PapelImpresora.values) {
      final doc = DocumentoEscPos(papel)..columnasExtremos('TOTAL', '10.00');
      final linea = String.fromCharCodes(doc.terminar().skip(5).take(papel.columnas));
      expect(linea.startsWith('TOTAL'), isTrue);
      expect(linea.endsWith('10.00'), isTrue);
    }
  });

  test('el ticket incluye serie, total y QR solo si es electronico', () {
    final comprobante = <String, dynamic>{
      'tipo': '03',
      'serie': 'B001',
      'correlativo': 7,
      'total': '10.00',
      'qr': 'DATOS',
      'items': [
        {'descripcion': 'Pan', 'cantidad': '1', 'precio_unitario': '10', 'total': '10'},
      ],
    };
    final texto = String.fromCharCodes(
      construirTicket(
        comprobante: comprobante,
        empresa: const {'ruc': '20123456789'},
        papel: PapelImpresora.mm80,
      ),
    );
    expect(texto, contains('B001-00000007'));
    expect(texto, contains('DATOS'));

    final notaVenta = String.fromCharCodes(
      construirTicket(
        comprobante: {...comprobante, 'tipo': 'NV'},
        empresa: const {},
        papel: PapelImpresora.mm58,
      ),
    );
    expect(notaVenta, isNot(contains('DATOS')));
  });
}
