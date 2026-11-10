import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../formatos/formatos.dart';
import '../tema/tema.dart';

class TextoDinero extends StatelessWidget {
  const TextoDinero(
    this.importe, {
    this.moneda = 'PEN',
    this.estilo,
    this.color,
    this.alineacion,
    super.key,
  });

  final Decimal importe;
  final String moneda;
  final TextStyle? estilo;
  final Color? color;
  final TextAlign? alineacion;

  @override
  Widget build(BuildContext context) {
    final base = estilo ?? DefaultTextStyle.of(context).style;
    return Text(
      formatearDinero(importe, moneda: moneda),
      textAlign: alineacion,
      maxLines: 1,
      style: base.copyWith(fontFeatures: figurasTabulares, color: color),
    );
  }
}
