import 'dart:typed_data';

import 'impresora.dart';

class DocumentoEscPos {
  DocumentoEscPos(this.papel) {
    _bytes.add(const [0x1B, 0x40, 0x1B, 0x74, 0x10]);
  }

  final PapelImpresora papel;
  final BytesBuilder _bytes = BytesBuilder();

  int get columnas => papel.columnas;

  void centrado(String texto, {bool negrita = false}) {
    _alinear(1);
    _linea(texto, negrita: negrita);
    _alinear(0);
  }

  void texto(String contenido, {bool negrita = false}) {
    _linea(contenido, negrita: negrita);
  }

  void columnasExtremos(
    String izquierda,
    String derecha, {
    bool negrita = false,
  }) {
    final maximoIzquierda = columnas - derecha.length - 1;
    final recortada = izquierda.length > maximoIzquierda
        ? izquierda.substring(0, maximoIzquierda < 0 ? 0 : maximoIzquierda)
        : izquierda;
    final relleno = columnas - recortada.length - derecha.length;
    _linea(
      '$recortada${' ' * (relleno < 1 ? 1 : relleno)}$derecha',
      negrita: negrita,
    );
  }

  void separador() => _linea('-' * columnas);

  void qr(String contenido) {
    final datos = _codificar(contenido);
    final longitud = datos.length + 3;
    _alinear(1);
    _bytes.add(const [0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    _bytes.add([
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x43,
      papel == PapelImpresora.mm58 ? 0x05 : 0x06,
    ]);
    _bytes.add(const [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);
    _bytes.add([
      0x1D,
      0x28,
      0x6B,
      longitud & 0xFF,
      longitud >> 8,
      0x31,
      0x50,
      0x30,
    ]);
    _bytes.add(datos);
    _bytes.add(const [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
    _bytes.addByte(0x0A);
    _alinear(0);
  }

  Uint8List terminar() {
    _bytes.add(const [0x1B, 0x64, 0x04, 0x1D, 0x56, 0x01]);
    return _bytes.toBytes();
  }

  void _alinear(int modo) => _bytes.add([0x1B, 0x61, modo]);

  void _linea(String contenido, {bool negrita = false}) {
    if (negrita) _bytes.add(const [0x1B, 0x45, 0x01]);
    _bytes.add(_codificar(contenido));
    _bytes.addByte(0x0A);
    if (negrita) _bytes.add(const [0x1B, 0x45, 0x00]);
  }

  Uint8List _codificar(String contenido) => Uint8List.fromList([
    for (final unidad in contenido.codeUnits) unidad > 0xFF ? 0x3F : unidad,
  ]);
}
