import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';

enum SunatStatus {
  pendiente('Pendiente'),
  procesando('Procesando'),
  aceptado('Aceptado'),
  observado('Observado'),
  rechazado('Rechazado'),
  anulado('Anulado'),
  error('Error');

  const SunatStatus(this.label);
  final String label;

  static SunatStatus fromApi(String? value) {
    final v = value?.toLowerCase();
    return SunatStatus.values.firstWhere(
      (s) => s.name == v,
      orElse: () => SunatStatus.pendiente,
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.compact = false});

  final SunatStatus status;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fg, bg, icon) = switch (status) {
      SunatStatus.aceptado => (
        p.success,
        p.successSoft,
        LucideIcons.circleCheck,
      ),
      SunatStatus.observado => (
        p.warning,
        p.warningSoft,
        LucideIcons.triangleAlert,
      ),
      SunatStatus.rechazado => (p.danger, p.dangerSoft, LucideIcons.circleX),
      SunatStatus.error => (p.danger, p.dangerSoft, LucideIcons.circleAlert),
      SunatStatus.anulado => (p.textMuted, p.surfaceMuted, LucideIcons.ban),
      SunatStatus.pendiente ||
      SunatStatus.procesando => (p.brand, p.brandSoft, LucideIcons.clock),
    };

    return Semantics(
      label: 'SUNAT: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpace.x1 + 2 : AppSpace.x2 + 2,
          vertical: AppSpace.x1,
        ),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadii.pillAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            if (!compact) ...[
              const SizedBox(width: AppSpace.x1 + 2),
              Text(
                status.label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
