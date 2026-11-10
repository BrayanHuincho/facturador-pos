import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/formatos/formatos.dart';
import '../tokens/colors.dart';
import '../tokens/dimens.dart';
import '../typography.dart';
import 'icon_chip.dart';
import 'money_text.dart';
import 'status_badge.dart';

BoxDecoration v2CardDecoration(
  AppPalette p, {
  Color? border,
  double borderWidth = 1,
}) => BoxDecoration(
  color: p.surface,
  borderRadius: BorderRadius.circular(AppV2.cardRadius),
  border: Border.all(color: border ?? p.border, width: borderWidth),
  boxShadow: AppElevation.e2,
);

class ListCard extends StatelessWidget {
  const ListCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.dimmed = false,
    this.titleMaxLines = 2,
    this.padding = const EdgeInsets.all(AppSpace.x3),
    this.margin = EdgeInsets.zero,
    this.semanticLabel,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;

  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final bool dimmed;
  final int titleMaxLines;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final content = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            Opacity(opacity: dimmed ? 0.55 : 1, child: leading),
            const SizedBox(width: AppSpace.x3),
          ],
          Expanded(
            child: Opacity(
              opacity: dimmed ? 0.55 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitleWidget != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: subtitleWidget,
                    )
                  else if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: p.textMuted),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.x2),
            trailing!,
          ],
        ],
      ),
    );

    return Padding(
      padding: margin,
      child: Semantics(
        label: semanticLabel,
        child: DecoratedBox(
          decoration: v2CardDecoration(p),
          child: Material(
            type: MaterialType.transparency,
            child: onTap == null && onLongPress == null
                ? content
                : InkWell(
                    borderRadius: BorderRadius.circular(AppV2.cardRadius),
                    onTap: onTap,
                    onLongPress: onLongPress,
                    child: content,
                  ),
          ),
        ),
      ),
    );
  }
}

class DocumentRow extends StatelessWidget {
  const DocumentRow({
    super.key,
    required this.numero,
    required this.cliente,
    required this.fecha,
    required this.total,
    required this.estado,
    this.factura = false,
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  final String numero;
  final String cliente;
  final String fecha;
  final Decimal total;
  final SunatStatus estado;

  final bool factura;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return ListCard(
      margin: margin,
      onTap: onTap,
      titleMaxLines: 1,
      semanticLabel: '${factura ? 'Factura' : 'Boleta'} $numero',
      leading: IconChip(
        factura ? LucideIcons.building2 : LucideIcons.receiptText,
        color: factura ? const Color(0xFF7C3AED) : p.brand,
      ),
      title: numero,
      subtitleWidget: Text(
        '$cliente · $fecha',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.bodySmall?.copyWith(color: p.textMuted),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(total, size: MoneySize.small, color: p.text),
          const SizedBox(height: AppSpace.x1),
          StatusBadge(estado),
        ],
      ),
    );
  }
}

class SelectableCard extends StatelessWidget {
  const SelectableCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.selected,
    required this.onTap,
    this.direction = Axis.horizontal,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;

  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;
  final Axis direction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final vertical = direction == Axis.vertical;
    final textos = Column(
      crossAxisAlignment: vertical
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: vertical ? TextAlign.center : TextAlign.start,
          style: text.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? p.brand : p.text,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: vertical ? TextAlign.center : TextAlign.start,
              style: text.bodySmall?.copyWith(color: p.textMuted),
            ),
          ),
      ],
    );
    final body = vertical
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x3,
              AppSpace.x4,
              AppSpace.x3,
              AppSpace.x3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(height: AppSpace.x2),
                ],
                textos,
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x3,
              AppSpace.x3,
              AppSpace.x8,
              AppSpace.x3,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpace.x3),
                ],
                Expanded(child: textos),
              ],
            ),
          );

    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    p.brand.withValues(alpha: p.isDark ? 0.14 : 0.05),
                    p.surface,
                  )
                : p.surface,
            borderRadius: BorderRadius.circular(AppV2.cardRadius),
            border: Border.all(
              color: selected ? p.brand : p.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? AppElevation.none : AppElevation.e2,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppV2.cardRadius),
              onTap: enabled ? onTap : null,
              child: Stack(
                children: [
                  body,
                  Positioned(
                    top: AppSpace.x2,
                    right: AppSpace.x2,
                    child: AnimatedScale(
                      duration: AppMotion.fast,
                      scale: selected ? 1 : 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: p.brand,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.check,
                          size: 13,
                          color: p.onBrand,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    this.amount,
    this.value,
    this.footer,
    this.color,
    this.onTap,
    this.loading = false,
  }) : assert(amount != null || value != null || loading);

  final IconData icon;
  final String label;

  final Decimal? amount;

  final String? value;
  final String? footer;
  final Color? color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final c = color ?? p.brand;
    final cifra = text.headlineMedium?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final content = Padding(
      padding: const EdgeInsets.all(AppSpace.x3 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconChip(icon, color: c, size: 38),
          const SizedBox(height: AppSpace.x3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: p.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpace.x1),
          if (loading)
            Container(
              height: 24,
              width: 96,
              decoration: BoxDecoration(
                color: p.surfaceMuted,
                borderRadius: AppRadii.smAll,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: amount != null
                  ? Text(
                      _soles(amount!),
                      softWrap: false,
                      style: AppTypography.money(cifra!),
                    )
                  : Text(
                      value!,
                      softWrap: false,
                      style: AppTypography.money(cifra!),
                    ),
            ),
          if (footer != null) ...[
            const SizedBox(height: AppSpace.x1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                footer!,
                softWrap: false,
                style: text.bodySmall?.copyWith(color: p.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
    return DecoratedBox(
      decoration: v2CardDecoration(p),
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? content
            : InkWell(
                borderRadius: BorderRadius.circular(AppV2.cardRadius),
                onTap: onTap,
                child: content,
              ),
      ),
    );
  }

  static String _soles(Decimal d) => formatearDinero(d);
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.action,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.x4,
      0,
      AppSpace.x4,
      AppSpace.x4,
    ),
  });

  final String title;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: v2CardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x4,
              AppSpace.x3,
              AppSpace.x2,
              AppSpace.x2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                ?action,
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
