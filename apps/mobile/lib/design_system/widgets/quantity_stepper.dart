import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';
import '../typography.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: 'Cantidad',
      value: '$value',
      increasedValue: value < max ? '${value + 1}' : null,
      decreasedValue: value > min ? '${value - 1}' : null,
      onIncrease: value < max ? () => onChanged(value + 1) : null,
      onDecrease: value > min ? () => onChanged(value - 1) : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadii.mdAll,
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              icon: LucideIcons.minus,
              tooltip: 'Quitar uno',
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40),
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: AppTypography.money(
                  Theme.of(context).textTheme.titleMedium!,
                ),
              ),
            ),
            _StepButton(
              icon: LucideIcons.plus,
              tooltip: 'Agregar uno',
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: AppSizes.iconMd),
    color: context.palette.brand,
    disabledColor: context.palette.textMuted.withValues(alpha: 0.4),
    constraints: const BoxConstraints.tightFor(
      width: AppSizes.minTouch,
      height: AppSizes.minTouch,
    ),
  );
}
