import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';

class ModoPruebaBanner extends StatelessWidget {
  const ModoPruebaBanner({
    super.key,
    this.message = 'Modo prueba: sin validez ante SUNAT',
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x4,
          vertical: AppSpace.x1 + 2,
        ),
        decoration: BoxDecoration(
          color: p.warningSoft,
          border: Border(
            bottom: BorderSide(color: p.warning.withValues(alpha: 0.35)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.flaskConical,
              size: AppSizes.iconSm,
              color: p.warning,
            ),
            const SizedBox(width: AppSpace.x2),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: p.warning),
              ),
            ),
            if (actionLabel != null && onAction != null)
              InkWell(
                onTap: onAction,
                borderRadius: AppRadii.smAll,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.x1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionLabel!,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: p.warning,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
                                decorationColor: p.warning,
                              ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: AppSizes.iconSm,
                          color: p.warning,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
