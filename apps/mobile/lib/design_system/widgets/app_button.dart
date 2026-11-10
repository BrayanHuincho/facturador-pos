import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize {
  medium(AppSizes.minTouch, AppSpace.x5),

  large(AppSizes.buttonLarge, AppSpace.x6);

  const AppButtonSize(this.height, this.padding);
  final double height;
  final double padding;
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.leading,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;

  final Widget? leading;
  final bool loading;

  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg, side) = switch (variant) {
      AppButtonVariant.primary => (p.brand, p.onBrand, BorderSide.none),
      AppButtonVariant.secondary => (
        p.surface,
        p.text,
        BorderSide(color: p.border),
      ),
      AppButtonVariant.ghost => (Colors.transparent, p.brand, BorderSide.none),
      AppButtonVariant.danger =>
        p.isDark
            ? (
                p.dangerSoft,
                p.danger,
                BorderSide(color: p.danger.withValues(alpha: 0.35)),
              )
            : (p.danger, p.onBrand, BorderSide.none),
    };
    final enabled = onPressed != null && !loading;
    final textStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: fg);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: AppSizes.iconMd,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        else if (leading != null)
          leading!
        else if (icon != null)
          Icon(icon, size: AppSizes.iconMd, color: fg),
        if (loading || icon != null || leading != null)
          const SizedBox(width: AppSpace.x2),
        Flexible(
          child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? '$label, procesando' : null,
      excludeSemantics: loading,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.mdAll,
            side: side,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size.height,
                minWidth: AppSizes.minTouch,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size.padding),
                child: Center(
                  widthFactor: expand ? null : 1,
                  heightFactor: 1,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
