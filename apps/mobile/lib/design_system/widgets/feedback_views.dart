import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/errores/errores.dart';
import '../tokens/colors.dart';
import '../tokens/dimens.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = LucideIcons.inbox,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _Centered(
    icon: icon,
    iconColor: context.palette.textMuted,
    iconBackground: context.palette.surfaceMuted,
    title: title,
    message: message,
    action: actionLabel != null && onAction != null
        ? AppButton(
            label: actionLabel!,
            onPressed: onAction,
            variant: AppButtonVariant.secondary,
          )
        : null,
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.title = 'Algo salió mal',
    this.onRetry,
  });

  final Object error;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final detalle = error;
    return _Centered(
      icon: LucideIcons.cloudOff,
      iconColor: p.danger,
      iconBackground: p.dangerSoft,
      title: title,
      message: detalle is String ? detalle : mensajeDeError(detalle),
      action: onRetry == null
          ? null
          : AppButton(
              label: 'Reintentar',
              icon: LucideIcons.refreshCw,
              onPressed: onRetry,
              variant: AppButtonVariant.secondary,
            ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.x6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: AppSizes.iconLg),
              ),
              const SizedBox(height: AppSpace.x4),
              Text(title, style: t.titleMedium, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: AppSpace.x1 + 2),
                Text(
                  message!,
                  style: t.bodyMedium?.copyWith(
                    color: context.palette.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpace.x5),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
