import 'package:flutter/material.dart';

abstract final class AppColors {
  static const _paleta = String.fromEnvironment(
    'PALETA',
    defaultValue: 'acero',
  );
  static const brand = _paleta == 'azur'
      ? Color(0xFF356DDB)
      : _paleta == 'real'
      ? Color(0xFF3366CC)
      : Color(0xFF2D5BBA);
  static const brandPressed = _paleta == 'azur'
      ? Color(0xFF2A58B8)
      : _paleta == 'real'
      ? Color(0xFF2A55AB)
      : Color(0xFF244B9A);
  static const header = _paleta == 'azur'
      ? Color(0xFF1E3A8A)
      : _paleta == 'real'
      ? Color(0xFF2B57B0)
      : Color(0xFF264C96);
  static const brandSoft = Color(0xFFE8EEF9);
  static const brandOnDark = Color(0xFF8CACE6);

  static const ink = Color(0xFF0E1B33);

  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF4F6FA);
  static const neutral100 = Color(0xFFEEF1F6);
  static const neutral200 = Color(0xFFE3E8F0);
  static const neutral300 = Color(0xFFC8D0DC);
  static const neutral400 = Color(0xFF98A3B5);
  static const neutral500 = Color(0xFF687488);
  static const neutral600 = Color(0xFF4C576A);
  static const navInactive = Color(0xFF7A8699);
  static const neutral700 = Color(0xFF343F51);
  static const neutral800 = Color(0xFF1E293B);

  static const success = Color(0xFF137238);
  static const successSoft = Color(0xFFDDF5E5);
  static const warning = Color(0xFFA04A07);
  static const warningSoft = Color(0xFFFDF0D5);
  static const danger = Color(0xFFC62828);
  static const dangerSoft = Color(0xFFFCE6E6);

  static const darkBackground = Color(0xFF0F1522);
  static const darkSurface = Color(0xFF182130);
  static const darkSurfaceMuted = Color(0xFF212B3C);
  static const darkSurfaceRaised = Color(0xFF232E40);
  static const darkSurfaceSheet = Color(0xFF1D2636);
  static const darkInputFill = Color(0xFF131A27);
  static const darkBorder = Color(0xFF2C3749);
  static const darkBorderStrong = Color(0xFF465368);
  static const darkText = Color(0xFFE7EBF2);
  static const darkTextMuted = Color(0xFFA9B4C5);
  static const darkNavInactive = Color(0xFF9AA6B8);
  static const darkHeader = Color(0xFF1E2F50);
  static const darkOnHeader = Color(0xFFF1F4F9);
  static const darkSearchFill = Color(0xFF2C3F63);
  static const darkSearchHint = Color(0xFFB4C0D4);
  static const darkPlate = Color(0xFFF2F4F8);
  static const darkSuccess = Color(0xFF7FCFA0);
  static const darkWarning = Color(0xFFE8BC72);
  static const darkDanger = Color(0xFFF2A0A0);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    this.header = AppColors.header,
    this.isDark = false,
    this.surfaceRaised = AppColors.neutral0,
    this.surfaceSheet = AppColors.neutral0,
    this.inputFill = AppColors.neutral0,
    this.borderStrong = AppColors.neutral300,
    this.navInactive = AppColors.navInactive,
    this.onHeader = AppColors.neutral0,
    this.searchFill = AppColors.neutral0,
    this.searchText = AppColors.ink,
    this.searchHint = AppColors.neutral500,
    this.plate = AppColors.neutral0,
  });

  static const light = AppPalette(
    background: AppColors.neutral50,
    surface: AppColors.neutral0,
    surfaceMuted: AppColors.neutral100,
    border: AppColors.neutral200,
    text: AppColors.ink,
    textMuted: AppColors.neutral600,
    brand: AppColors.brand,
    onBrand: AppColors.neutral0,
    brandSoft: AppColors.brandSoft,
    success: AppColors.success,
    successSoft: AppColors.successSoft,
    warning: AppColors.warning,
    warningSoft: AppColors.warningSoft,
    danger: AppColors.danger,
    dangerSoft: AppColors.dangerSoft,
  );

  static const dark = AppPalette(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceMuted: AppColors.darkSurfaceMuted,
    border: AppColors.darkBorder,
    text: AppColors.darkText,
    textMuted: AppColors.darkTextMuted,
    brand: AppColors.brandOnDark,
    onBrand: AppColors.ink,
    brandSoft: Color(0xFF243654),
    success: AppColors.darkSuccess,
    successSoft: Color(0xFF1A3329),
    warning: AppColors.darkWarning,
    warningSoft: Color(0xFF3A2E1B),
    danger: AppColors.darkDanger,
    dangerSoft: Color(0xFF40242A),
    header: AppColors.darkHeader,
    isDark: true,
    surfaceRaised: AppColors.darkSurfaceRaised,
    surfaceSheet: AppColors.darkSurfaceSheet,
    inputFill: AppColors.darkInputFill,
    borderStrong: AppColors.darkBorderStrong,
    navInactive: AppColors.darkNavInactive,
    onHeader: AppColors.darkOnHeader,
    searchFill: AppColors.darkSearchFill,
    searchText: AppColors.darkText,
    searchHint: AppColors.darkSearchHint,
    plate: AppColors.darkPlate,
  );

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color brand;
  final Color onBrand;
  final Color brandSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color header;
  final bool isDark;
  final Color surfaceRaised;
  final Color surfaceSheet;
  final Color inputFill;
  final Color borderStrong;
  final Color navInactive;
  final Color onHeader;
  final Color searchFill;
  final Color searchText;
  final Color searchHint;
  final Color plate;

  Color tono(Color c) {
    if (!isDark) return c;
    if (c == AppColors.ink) return textMuted;
    if (c.computeLuminance() >= 0.30) return c;
    final h = HSLColor.fromColor(c);
    return h
        .withSaturation(h.saturation.clamp(0.0, 0.55))
        .withLightness(0.74)
        .toColor();
  }

  double get alfaTinte => isDark ? 0.17 : 0.11;

  List<BoxShadow> get sombraFlotante => isDark
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1F0E1B33),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ];

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? brand,
    Color? onBrand,
    Color? brandSoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? header,
    Color? surfaceRaised,
    Color? surfaceSheet,
    Color? inputFill,
    Color? borderStrong,
    Color? navInactive,
    Color? onHeader,
    Color? searchFill,
    Color? searchText,
    Color? searchHint,
    Color? plate,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    border: border ?? this.border,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    brand: brand ?? this.brand,
    onBrand: onBrand ?? this.onBrand,
    brandSoft: brandSoft ?? this.brandSoft,
    success: success ?? this.success,
    successSoft: successSoft ?? this.successSoft,
    warning: warning ?? this.warning,
    warningSoft: warningSoft ?? this.warningSoft,
    danger: danger ?? this.danger,
    dangerSoft: dangerSoft ?? this.dangerSoft,
    header: header ?? this.header,
    isDark: isDark,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceSheet: surfaceSheet ?? this.surfaceSheet,
    inputFill: inputFill ?? this.inputFill,
    borderStrong: borderStrong ?? this.borderStrong,
    navInactive: navInactive ?? this.navInactive,
    onHeader: onHeader ?? this.onHeader,
    searchFill: searchFill ?? this.searchFill,
    searchText: searchText ?? this.searchText,
    searchHint: searchHint ?? this.searchHint,
    plate: plate ?? this.plate,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      border: l(border, other.border),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      brand: l(brand, other.brand),
      onBrand: l(onBrand, other.onBrand),
      brandSoft: l(brandSoft, other.brandSoft),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      header: l(header, other.header),
      isDark: t < 0.5 ? isDark : other.isDark,
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceSheet: l(surfaceSheet, other.surfaceSheet),
      inputFill: l(inputFill, other.inputFill),
      borderStrong: l(borderStrong, other.borderStrong),
      navInactive: l(navInactive, other.navInactive),
      onHeader: l(onHeader, other.onHeader),
      searchFill: l(searchFill, other.searchFill),
      searchText: l(searchText, other.searchText),
      searchHint: l(searchHint, other.searchHint),
      plate: l(plate, other.plate),
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
