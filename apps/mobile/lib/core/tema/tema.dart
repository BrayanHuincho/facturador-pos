import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

const figurasTabulares = AppTypography.tabular;

@immutable
class ColoresPos extends ThemeExtension<ColoresPos> {
  const ColoresPos({
    required this.exito,
    required this.exitoFondo,
    required this.advertencia,
    required this.advertenciaFondo,
    required this.papelTicket,
    required this.tintaTicket,
    required this.fondoMarca,
  });

  final Color exito;
  final Color exitoFondo;
  final Color advertencia;
  final Color advertenciaFondo;
  final Color papelTicket;
  final Color tintaTicket;
  final Color fondoMarca;

  factory ColoresPos.desdePaleta(AppPalette p) => ColoresPos(
    exito: p.success,
    exitoFondo: p.successSoft,
    advertencia: p.warning,
    advertenciaFondo: p.warningSoft,
    papelTicket: p.surface,
    tintaTicket: p.text,
    fondoMarca: p.header,
  );

  static final claro = ColoresPos.desdePaleta(AppPalette.light);
  static final oscuro = ColoresPos.desdePaleta(AppPalette.dark);

  @override
  ColoresPos copyWith({
    Color? exito,
    Color? exitoFondo,
    Color? advertencia,
    Color? advertenciaFondo,
    Color? papelTicket,
    Color? tintaTicket,
    Color? fondoMarca,
  }) => ColoresPos(
    exito: exito ?? this.exito,
    exitoFondo: exitoFondo ?? this.exitoFondo,
    advertencia: advertencia ?? this.advertencia,
    advertenciaFondo: advertenciaFondo ?? this.advertenciaFondo,
    papelTicket: papelTicket ?? this.papelTicket,
    tintaTicket: tintaTicket ?? this.tintaTicket,
    fondoMarca: fondoMarca ?? this.fondoMarca,
  );

  @override
  ColoresPos lerp(ThemeExtension<ColoresPos>? other, double t) {
    if (other is! ColoresPos) return this;
    return ColoresPos(
      exito: Color.lerp(exito, other.exito, t)!,
      exitoFondo: Color.lerp(exitoFondo, other.exitoFondo, t)!,
      advertencia: Color.lerp(advertencia, other.advertencia, t)!,
      advertenciaFondo: Color.lerp(
        advertenciaFondo,
        other.advertenciaFondo,
        t,
      )!,
      papelTicket: Color.lerp(papelTicket, other.papelTicket, t)!,
      tintaTicket: Color.lerp(tintaTicket, other.tintaTicket, t)!,
      fondoMarca: Color.lerp(fondoMarca, other.fondoMarca, t)!,
    );
  }
}

extension TemaContexto on BuildContext {
  ColoresPos get coloresPos => Theme.of(this).extension<ColoresPos>()!;
  ColorScheme get colores => Theme.of(this).colorScheme;
  TextTheme get textos => Theme.of(this).textTheme;
}

final ThemeData temaClaro = AppTheme.light.copyWith(
  extensions: [AppPalette.light, ColoresPos.claro],
);

final ThemeData temaOscuro = AppTheme.dark.copyWith(
  extensions: [AppPalette.dark, ColoresPos.oscuro],
);
