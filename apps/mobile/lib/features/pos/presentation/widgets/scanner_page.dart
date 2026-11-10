import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
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
    appBar: AppBar(title: const Text('Escanear código')),
    body: MobileScanner(onDetect: _alDetectar),
  );
}
