import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';
import 'app_bottom_sheet.dart';

class AppSelectorOption<T> {
  const AppSelectorOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
}

abstract final class AppSelectorSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<AppSelectorOption<T>> options,
    T? selected,
    String? footerLabel,
    IconData? footerIcon,
    VoidCallback? onFooter,
  }) {
    return AppBottomSheet.show<T>(
      context,
      title: title,
      footer: footerLabel == null
          ? null
          : Builder(
              builder: (sheet) => SizedBox(
                height: AppSizes.minTouch,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    onFooter?.call();
                  },
                  icon: footerIcon == null
                      ? null
                      : Icon(footerIcon, size: AppSizes.iconMd),
                  label: Text(footerLabel),
                ),
              ),
            ),
      child: Builder(
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final o in options)
              _Fila<T>(
                option: o,
                selected: o.value == selected,
                onTap: () => Navigator.of(sheet).pop(o.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _Fila<T> extends StatelessWidget {
  const _Fila({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppSelectorOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.brand.withValues(alpha: 0.07) : Colors.transparent,
        borderRadius: AppRadii.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.x3,
                vertical: AppSpace.x2,
              ),
              child: Row(
                children: [
                  if (option.leading != null) ...[
                    option.leading!,
                    const SizedBox(width: AppSpace.x3),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleSmall?.copyWith(
                            color: selected ? p.brand : p.text,
                          ),
                        ),
                        if (option.subtitle != null)
                          Text(option.subtitle!, style: t.bodySmall),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: AppSpace.x3),
                    Icon(
                      LucideIcons.check,
                      size: AppSizes.iconMd,
                      color: p.brand,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
