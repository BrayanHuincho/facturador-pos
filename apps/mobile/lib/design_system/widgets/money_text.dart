import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../core/formatos/formatos.dart';
import '../tokens/colors.dart';
import '../typography.dart';

enum MoneySize { small, medium, large, display }

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.size = MoneySize.medium,
    this.color,
    this.showSymbol = true,
    this.strikethrough = false,
    this.textAlign,
  });

  final Decimal amount;
  final MoneySize size;
  final Color? color;
  final bool showSymbol;

  final bool strikethrough;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final base = switch (size) {
      MoneySize.small => t.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
      MoneySize.medium => t.titleMedium!.copyWith(fontWeight: FontWeight.w700),
      MoneySize.large => t.headlineSmall!.copyWith(fontWeight: FontWeight.w800),
      MoneySize.display => AppTypography.totalDisplay.copyWith(
        color: context.palette.text,
      ),
    };
    final text = (showSymbol
        ? formatearDinero(amount)
        : formatearNumero(amount));

    return Text(
      text,
      textAlign: textAlign,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
      semanticsLabel: formatearDinero(amount),
      style: AppTypography.money(base).copyWith(
        color: color,
        decoration: strikethrough ? TextDecoration.lineThrough : null,
      ),
    );
  }
}
