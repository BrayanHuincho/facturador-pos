import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../design_system/design_system.dart';

const _margenVisor = AppSpace.x4;
const _anchoMaximoVisor = 720.0;
const _dpiMaximo = 400.0;

double dpiParaVisor({
  required double anchoPt,
  required double anchoDp,
  required double densidad,
}) {
  const sobremuestreo = 2.0;
  final dpi = 72 * anchoDp * densidad * sobremuestreo / anchoPt;
  return math.min(dpi, _dpiMaximo);
}

class PaginaPdf {
  const PaginaPdf({required this.png, required this.ancho, required this.alto});

  final Uint8List png;
  final double ancho;
  final double alto;
}

Future<List<PaginaPdf>> dibujarPaginasPdf(
  Uint8List bytes, {
  required double anchoDp,
  required double densidad,
}) async {
  final muestra = await Printing.raster(bytes, pages: const [0], dpi: 72).first;
  final dpi = dpiParaVisor(
    anchoPt: muestra.width.toDouble(),
    anchoDp: anchoDp,
    densidad: densidad,
  );
  final paginas = <PaginaPdf>[];
  await for (final raster in Printing.raster(bytes, dpi: dpi)) {
    paginas.add(
      PaginaPdf(
        png: await raster.toPng(),
        ancho: raster.width.toDouble(),
        alto: raster.height.toDouble(),
      ),
    );
  }
  return paginas;
}

class VisorPdf extends StatefulWidget {
  const VisorPdf({required this.bytes, super.key});

  final Uint8List bytes;

  @override
  State<VisorPdf> createState() => _VisorPdfState();
}

class _VisorPdfState extends State<VisorPdf> {
  Future<List<PaginaPdf>>? _paginas;
  Uint8List? _bytesDibujados;
  (double, double)? _pedido;
  List<PaginaPdf>? _ultimasPaginas;

  Future<List<PaginaPdf>> _paginasPara(double anchoDp, double densidad) {
    final mismo =
        _paginas != null &&
        identical(_bytesDibujados, widget.bytes) &&
        _pedido == (anchoDp, densidad);
    if (mismo) return _paginas!;
    _pedido = (anchoDp, densidad);
    _bytesDibujados = widget.bytes;
    return _paginas = dibujarPaginasPdf(
      widget.bytes,
      anchoDp: anchoDp,
      densidad: densidad,
    ).then((paginas) => _ultimasPaginas = paginas);
  }

  @override
  Widget build(BuildContext context) {
    final densidad = MediaQuery.devicePixelRatioOf(context);
    final fondo = context.palette.background;
    return ColoredBox(
      color: fondo,
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final anchoDp = math.min(
            restricciones.maxWidth - _margenVisor * 2,
            _anchoMaximoVisor,
          );
          return FutureBuilder<List<PaginaPdf>>(
            future: _paginasPara(anchoDp, densidad),
            builder: (context, instantanea) {
              if (instantanea.hasError) {
                return const Center(
                  child: Text('No se pudo dibujar el documento.'),
                );
              }
              final paginas = instantanea.data ?? _ultimasPaginas;
              if (paginas == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return InteractiveViewer(
                key: const ValueKey('visor-pdf'),
                constrained: false,
                minScale: 1,
                maxScale: 5,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: restricciones.maxWidth,
                    minHeight: restricciones.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(_margenVisor),
                    child: Column(
                      children: [
                        for (final (indice, pagina) in paginas.indexed) ...[
                          if (indice > 0) const SizedBox(height: AppSpace.x3),
                          _PaginaImagen(pagina: pagina, anchoDp: anchoDp),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PaginaImagen extends StatelessWidget {
  const _PaginaImagen({required this.pagina, required this.anchoDp});

  final PaginaPdf pagina;
  final double anchoDp;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0E1B33),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Image.memory(
        pagina.png,
        width: anchoDp,
        height: anchoDp * pagina.alto / pagina.ancho,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        semanticLabel: 'Documento',
      ),
    );
  }
}

class CargandoDocumento extends StatelessWidget {
  const CargandoDocumento({this.texto = 'Preparando documento…', super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: AppSpace.x3),
          Text(
            texto,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: p.textMuted),
          ),
        ],
      ),
    );
  }
}
