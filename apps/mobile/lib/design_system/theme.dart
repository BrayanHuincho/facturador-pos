import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens/colors.dart';
import 'tokens/dimens.dart';
import 'typography.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppPalette.light);
  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.brand,
      onPrimary: p.onBrand,
      primaryContainer: p.brandSoft,
      onPrimaryContainer: p.text,
      secondary: p.text,
      onSecondary: p.surface,
      error: p.danger,
      onError: brightness == Brightness.light
          ? AppColors.neutral0
          : AppColors.ink,
      errorContainer: p.dangerSoft,
      onErrorContainer: p.danger,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textMuted,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.background,
      surfaceContainer: p.surfaceMuted,
      surfaceContainerHigh: p.isDark ? p.surfaceRaised : p.surfaceMuted,
      surfaceContainerHighest: p.surfaceMuted,
      outline: p.isDark ? p.borderStrong : p.border,
      outlineVariant: p.border,
    );
    final text = AppTypography.textTheme(p.text, p.textMuted);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: AppRadii.mdAll,
      borderSide: BorderSide(color: c, width: w),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: p.background,
      extensions: [p],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouch),
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouch),
          foregroundColor: p.text,
          textStyle: text.labelLarge,
          side: BorderSide(color: p.border),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.brand,
          minimumSize: const Size(48, AppSizes.minTouch),
          textStyle: text.labelLarge,
        ),
      ),
      dialogTheme: DialogThemeData(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x3,
          vertical: AppSpace.x6,
        ),
        constraints: const BoxConstraints(minWidth: 560, maxWidth: 560),
        backgroundColor: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.brand,
        unselectedLabelColor: p.navInactive,
        indicatorColor: p.brand,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
      ),
      listTileTheme: ListTileThemeData(iconColor: p.brand, textColor: p.text),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.brandSoft,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.header,
        foregroundColor: p.onHeader,
        iconTheme: IconThemeData(color: p.onHeader),
        actionsIconTheme: IconThemeData(color: p.onHeader),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: p.header,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall?.copyWith(
          color: p.onHeader,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.lgAll,
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.inputFill,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x4,
          vertical: AppSpace.x3 + 2,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: p.textMuted),
        border: border(p.isDark ? p.borderStrong : p.border),
        enabledBorder: border(p.isDark ? p.borderStrong : p.border),
        focusedBorder: border(p.brand, 2),
        errorBorder: border(p.danger),
        focusedErrorBorder: border(p.danger, 2),
        disabledBorder: border(p.border.withValues(alpha: 0.5)),
        errorStyle: text.bodySmall?.copyWith(color: p.danger),
      ),
      popupMenuTheme: PopupMenuThemeData(
        position: PopupMenuPosition.under,
        color: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: p.isDark ? 0.5 : 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.isDark ? p.borderStrong : p.border),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceSheet,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.isDark ? p.borderStrong : p.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? p.surfaceRaised : p.text,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: p.isDark ? p.text : p.surface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
      switchTheme: p.isDark
          ? SwitchThemeData(
              thumbColor: WidgetStateColor.resolveWith(
                (s) =>
                    s.contains(WidgetState.selected) ? p.onBrand : p.textMuted,
              ),
              trackColor: WidgetStateColor.resolveWith(
                (s) =>
                    s.contains(WidgetState.selected) ? p.brand : p.surfaceMuted,
              ),
              trackOutlineColor: WidgetStateColor.resolveWith(
                (s) =>
                    s.contains(WidgetState.selected) ? p.brand : p.borderStrong,
              ),
            )
          : null,
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.brand),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.brand,
        foregroundColor: p.onBrand,
        elevation: 1,
        focusElevation: 1,
        hoverElevation: 2,
        highlightElevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        extendedTextStyle: text.labelLarge,
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        backgroundColor: p.surface,
        selectedColor: p.text,
        side: BorderSide(color: p.border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        labelStyle: text.labelLarge?.copyWith(
          color: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.surface : p.text,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadii.smAll),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          backgroundColor: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.text : p.surface,
          ),
          foregroundColor: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.surface : p.text,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.brandSoft,
        height: 64,
      ),
    );
  }
}
