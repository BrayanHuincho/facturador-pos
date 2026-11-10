import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../comprobantes/domain/importes.dart';
import '../domain/reporte.dart';

const _fuenteRegular = 'assets/fonts/PlusJakartaSans-Regular.ttf';
const _fuenteNegrita = 'assets/fonts/PlusJakartaSans-Bold.ttf';
const _maximoProductos = 30;
const _azul = PdfColor.fromInt(0xFF2563EB);
const _gris = PdfColor.fromInt(0xFF64748B);
const _lineas = PdfColor.fromInt(0xFFE2E8F0);

class DatosReportePdf {
  const DatosReportePdf({
    required this.empresa,
    required this.desde,
    required this.hasta,
    required this.kpis,
    required this.porDia,
    required this.porMedio,
    required this.porProducto,
  });

  final String empresa;
  final DateTime desde;
  final DateTime hasta;
  final KpisReporte kpis;
  final List<FilaVenta> porDia;
  final List<FilaVenta> porMedio;
  final List<FilaVenta> porProducto;
}

Future<Uint8List> construirReportePdf(DatosReportePdf datos) async {
  final (regular, negrita) = await (
    rootBundle.load(_fuenteRegular),
    rootBundle.load(_fuenteNegrita),
  ).wait;
  return generarReportePdf(
    datos,
    tema: pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(negrita),
    ),
  );
}

Future<Uint8List> generarReportePdf(
  DatosReportePdf datos, {
  pw.ThemeData? tema,
  DateTime? generadoEn,
}) {
  final fecha = DateFormat('dd/MM/yyyy');
  final kpis = datos.kpis;
  final documento = pw.Document(title: 'Reporte de ventas');
  documento.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: tema,
      margin: const pw.EdgeInsets.all(36),
      header: (contexto) => contexto.pageNumber == 1
          ? pw.SizedBox()
          : pw.Text(
              'Reporte de ventas · ${datos.empresa}',
              style: const pw.TextStyle(fontSize: 8, color: _gris),
            ),
      footer: (contexto) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Página ${contexto.pageNumber} de ${contexto.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _gris),
        ),
      ),
      build: (_) => [
        pw.Text(datos.empresa, style: pw.TextStyle(fontSize: 11, color: _gris)),
        pw.SizedBox(height: 2),
        pw.Text(
          'Reporte de ventas',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Del ${fecha.format(datos.desde)} al ${fecha.format(datos.hasta)}',
          style: const pw.TextStyle(fontSize: 11, color: _gris),
        ),
        pw.SizedBox(height: 16),
        _resumen(kpis),
        pw.SizedBox(height: 18),
        if (datos.porMedio.isNotEmpty) ...[
          _titulo('Por medio de pago'),
          _tabla(datos.porMedio.map(etiquetaFilaMedio).toList()),
          pw.SizedBox(height: 16),
        ],
        if (datos.porProducto.isNotEmpty) ...[
          _titulo('Productos más vendidos'),
          _tabla(datos.porProducto.take(_maximoProductos).toList()),
          pw.SizedBox(height: 16),
        ],
        if (datos.porDia.isNotEmpty) ...[
          _titulo('Ventas por día'),
          _tabla(datos.porDia),
        ],
      ],
    ),
  );
  return documento.save();
}

pw.Widget _titulo(String texto) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Text(
    texto,
    style: pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: _azul,
    ),
  ),
);

pw.Widget _resumen(KpisReporte kpis) {
  final filas = <(String, String)>[
    ('Ventas brutas', formatearMoneda(kpis.ventasBrutas)),
    ('Notas de crédito', formatearMoneda(kpis.notasCredito)),
    ('Notas de débito', formatearMoneda(kpis.notasDebito)),
    ('IGV', formatearMoneda(kpis.igv)),
    ('Documentos', '${kpis.documentosVenta}'),
    ('Ticket promedio', formatearMoneda(kpis.ticketPromedio)),
  ];
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _lineas),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Ventas netas', style: const pw.TextStyle(fontSize: 11)),
            pw.Text(
              formatearMoneda(kpis.ventasNetas),
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _azul,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _lineas, height: 1),
        pw.SizedBox(height: 8),
        for (final (etiqueta, valor) in filas)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(etiqueta, style: const pw.TextStyle(fontSize: 10)),
                pw.Text(valor, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
      ],
    ),
  );
}

pw.Widget _tabla(List<FilaVenta> filas) {
  final total = filas.fold(Decimal.zero, (suma, fila) => suma + fila.total);
  pw.Widget celda(String texto, {bool derecha = false, bool negrita = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: pw.Text(
          texto,
          textAlign: derecha ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _lineas, width: 0.5),
      top: pw.BorderSide(color: _lineas, width: 0.5),
      bottom: pw.BorderSide(color: _lineas, width: 0.5),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(),
      1: pw.FixedColumnWidth(50),
      2: pw.FixedColumnWidth(90),
    },
    children: [
      pw.TableRow(
        children: [
          celda('Detalle', negrita: true),
          celda('Docs.', derecha: true, negrita: true),
          celda('Total', derecha: true, negrita: true),
        ],
      ),
      for (final fila in filas)
        pw.TableRow(
          children: [
            celda(fila.etiqueta),
            celda('${fila.documentos}', derecha: true),
            celda(formatearMoneda(fila.total), derecha: true),
          ],
        ),
      pw.TableRow(
        children: [
          celda('Total', negrita: true),
          celda('', derecha: true),
          celda(formatearMoneda(total), derecha: true, negrita: true),
        ],
      ),
    ],
  );
}
