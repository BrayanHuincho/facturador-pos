import 'package:decimal/decimal.dart';
import 'package:facturador_pos/features/reportes/data/reporte_pdf.dart';
import 'package:facturador_pos/features/reportes/domain/reporte.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('genera el PDF del reporte con los datos del periodo', () async {
    final kpis = KpisReporte(
      ventasBrutas: Decimal.parse('118'),
      notasCredito: Decimal.zero,
      notasDebito: Decimal.zero,
      ventasNetas: Decimal.parse('118'),
      igv: Decimal.parse('18'),
      documentosVenta: 2,
      ticketPromedio: Decimal.parse('59'),
    );
    final fila = FilaVenta(
      etiqueta: 'efectivo',
      total: Decimal.parse('118'),
      documentos: 2,
    );
    final bytes = await generarReportePdf(
      DatosReportePdf(
        empresa: 'ACME SAC',
        desde: DateTime(2026, 11),
        hasta: DateTime(2026, 11, 9),
        kpis: kpis,
        porDia: [fila],
        porMedio: [fila],
        porProducto: [fila],
      ),
    );
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });

  test('traduce los códigos de medio de pago', () {
    final fila = FilaVenta(
      etiqueta: 'transferencia',
      total: Decimal.one,
      documentos: 1,
    );
    expect(etiquetaFilaMedio(fila).etiqueta, 'Transferencia');
  });
}
