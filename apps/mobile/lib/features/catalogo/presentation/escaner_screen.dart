import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../design_system/design_system.dart';

class EscanerScreen extends StatefulWidget {
  const EscanerScreen({super.key});

  static Future<String?> abrir(BuildContext context) => Navigator.of(
    context,
    rootNavigator: true,
  ).push<String>(MaterialPageRoute(builder: (_) => const EscanerScreen()));

  @override
  State<EscanerScreen> createState() => _EscanerScreenState();
}

class _EscanerScreenState extends State<EscanerScreen> {
  bool _detectado = false;

  void _alDetectar(BarcodeCapture captura) {
    if (_detectado) return;
    for (final codigo in captura.barcodes) {
      final valor = codigo.rawValue;
      if (valor != null && valor.isNotEmpty) {
        _detectado = true;
        Navigator.of(context).pop(valor);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const AppHeader(title: 'Escanear código'),
        Expanded(child: MobileScanner(onDetect: _alDetectar)),
      ],
    ),
  );
}
