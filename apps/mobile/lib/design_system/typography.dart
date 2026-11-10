import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const fontFamily = 'PlusJakartaSans';

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(Color ink, Color muted) {
    TextStyle s(
      double size,
      FontWeight weight,
      double height, {
      Color? color,
      double spacing = 0,
    }) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color ?? ink,
    );

    return TextTheme(
      displayLarge: s(48, FontWeight.w800, 1.1, spacing: -1),
      displayMedium: s(40, FontWeight.w800, 1.1, spacing: -0.8),
      displaySmall: s(32, FontWeight.w700, 1.15, spacing: -0.5),
      headlineLarge: s(28, FontWeight.w700, 1.2, spacing: -0.4),
      headlineMedium: s(24, FontWeight.w700, 1.25, spacing: -0.3),
      headlineSmall: s(20, FontWeight.w700, 1.3, spacing: -0.2),
      titleLarge: s(18, FontWeight.w700, 1.3),
      titleMedium: s(16, FontWeight.w600, 1.35),
      titleSmall: s(14, FontWeight.w600, 1.4),
      bodyLarge: s(16, FontWeight.w400, 1.5),
      bodyMedium: s(14, FontWeight.w400, 1.5),
      bodySmall: s(12, FontWeight.w400, 1.45, color: muted),
      labelLarge: s(15, FontWeight.w600, 1.2),
      labelMedium: s(13, FontWeight.w600, 1.2),
      labelSmall: s(11, FontWeight.w600, 1.2, spacing: 0.4),
    );
  }

  static TextStyle money(TextStyle base) =>
      base.copyWith(fontFeatures: tabular);

  static const TextStyle totalDisplay = TextStyle(
    fontFamily: fontFamily,
    fontSize: 44,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -1,
    fontFeatures: tabular,
  );
}
