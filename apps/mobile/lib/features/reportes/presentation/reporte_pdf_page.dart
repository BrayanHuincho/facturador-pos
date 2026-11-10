import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';

import '../../../core/widgets/visor_pdf.dart';
import '../../../design_system/design_system.dart';

class ReportePdfPage extends StatelessWidget {
  const ReportePdfPage({required this.bytes, required this.nombre, super.key});

  final Uint8List bytes;
  final String nombre;

  Future<void> _compartir(BuildContext contexto) async {
    final toaster = AppToast.para(contexto);
    try {
      await Printing.sharePdf(bytes: bytes, filename: nombre);
    } catch (_) {
      toaster.error('No se pudo compartir el reporte.');
    }
  }

  Future<void> _imprimir(BuildContext contexto) async {
    final toaster = AppToast.para(contexto);
    try {
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: nombre);
    } catch (_) {
      toaster.error('No se pudo imprimir el reporte.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.background,
    body: Column(
      children: [
        AppHeader(
          title: 'Reporte de ventas',
          actions: [
            AppHeaderAction(
              icon: LucideIcons.printer,
              tooltip: 'Imprimir',
              onPressed: () => _imprimir(context),
            ),
            AppHeaderAction(
              icon: LucideIcons.share2,
              tooltip: 'Compartir',
              label: 'Compartir',
              onPressed: () => _compartir(context),
            ),
          ],
        ),
        Expanded(child: VisorPdf(bytes: bytes)),
      ],
    ),
  );
}
