import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';

class MarcaF extends StatelessWidget {
  const MarcaF({super.key, this.size = 40, this.onBrand = true});

  final double size;
  final bool onBrand;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _MarcaPainter(
      tile: onBrand ? context.palette.onHeader : context.palette.brand,
      letra: onBrand ? context.palette.header : context.palette.onBrand,
    ),
  );
}

class _MarcaPainter extends CustomPainter {
  const _MarcaPainter({required this.tile, required this.letra});

  final Color tile;
  final Color letra;

  @override
  void paint(Canvas canvas, Size s) {
    final u = s.width / 100;
    const dientes = 6;
    const alto = 6.0;
    const ancho = 84.0 / dientes;
    final papel = Path()
      ..moveTo(8 * u, 18 * u)
      ..quadraticBezierTo(8 * u, 4 * u, 22 * u, 4 * u)
      ..lineTo(78 * u, 4 * u)
      ..quadraticBezierTo(92 * u, 4 * u, 92 * u, 18 * u)
      ..lineTo(92 * u, 96 * u);
    for (var i = dientes; i > 0; i--) {
      final x = 8 + ancho * i;
      papel
        ..lineTo((x - ancho / 2) * u, (96 - alto) * u)
        ..lineTo((x - ancho) * u, 96 * u);
    }
    papel.close();
    canvas.drawPath(papel, Paint()..color = tile);

    final f = Paint()..color = letra;
    RRect barra(double x, double y, double w, double h) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * u, y * u, w * u, h * u),
          Radius.circular(3 * u),
        );
    canvas
      ..drawRRect(barra(29, 20, 15, 62), f)
      ..drawRRect(barra(29, 20, 43, 14), f)
      ..drawRRect(barra(29, 44, 34, 13), f);
  }

  @override
  bool shouldRepaint(_MarcaPainter old) =>
      old.tile != tile || old.letra != letra;
}

class MarcaFacturacion extends StatelessWidget {
  const MarcaFacturacion({super.key, this.onBrand = false, this.size = 32});

  final bool onBrand;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Facturador POS',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MarcaF(size: size, onBrand: onBrand),
        const SizedBox(width: AppSpace.x2),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Facturador POS',
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w800,
                fontSize: size * 0.62,
                height: 1.1,
                letterSpacing: -0.3,
                color: onBrand
                    ? context.palette.onHeader
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
