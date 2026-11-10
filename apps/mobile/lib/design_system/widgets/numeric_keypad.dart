import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/formatos/formatos.dart';
import '../tokens/colors.dart';
import '../tokens/dimens.dart';

sealed class KeypadKey {
  const KeypadKey();
}

final class DigitKey extends KeypadKey {
  const DigitKey(this.digit);
  final String digit;
}

final class DecimalKey extends KeypadKey {
  const DecimalKey();
}

final class BackspaceKey extends KeypadKey {
  const BackspaceKey();
}

class AmountInputController extends ValueNotifier<String> {
  AmountInputController({this.maxDecimals = 2, this.maxIntegerDigits = 7})
    : super('');

  final int maxDecimals;
  final int maxIntegerDigits;

  Decimal get amount => parseDecimal(value.endsWith('.') ? '${value}0' : value);

  void press(KeypadKey key) {
    final v = value;
    switch (key) {
      case BackspaceKey():
        if (v.isNotEmpty) value = v.substring(0, v.length - 1);
      case DecimalKey():
        if (maxDecimals == 0 || v.contains('.')) return;
        value = v.isEmpty ? '0.' : '$v.';
      case DigitKey(:final digit):
        final dot = v.indexOf('.');
        if (dot >= 0) {
          if (v.length - dot - 1 >= maxDecimals) return;
          value = '$v$digit';
        } else if (v == '0') {
          value = digit;
        } else if (v.length < maxIntegerDigits) {
          value = '$v$digit';
        }
    }
  }

  void clear() => value = '';
}

class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onKey,
    this.onClear,
    this.allowDecimal = true,
    this.haptics = true,
  });

  final ValueChanged<KeypadKey> onKey;
  final VoidCallback? onClear;
  final bool allowDecimal;
  final bool haptics;

  void _emit(KeypadKey key) {
    if (haptics) HapticFeedback.selectionClick();
    onKey(key);
  }

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> keys) => Row(
      children: [
        for (final k in keys)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x1),
              child: k,
            ),
          ),
      ],
    );
    _Key digit(String d) => _Key(label: d, onTap: () => _emit(DigitKey(d)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([digit('1'), digit('2'), digit('3')]),
        row([digit('4'), digit('5'), digit('6')]),
        row([digit('7'), digit('8'), digit('9')]),
        row([
          if (allowDecimal)
            _Key(
              label: '.',
              semantics: 'Punto decimal',
              onTap: () => _emit(const DecimalKey()),
            )
          else
            const SizedBox(height: AppSizes.keypadKey),
          digit('0'),
          _Key(
            icon: LucideIcons.delete,
            semantics: 'Borrar',
            onTap: () => _emit(const BackspaceKey()),
            onLongPress: onClear,
          ),
        ]),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.semantics,
    required this.onTap,
    this.onLongPress,
  });

  final String? label;
  final IconData? icon;
  final String? semantics;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: semantics ?? label,
      excludeSemantics: true,
      child: Material(
        color: p.surfaceMuted,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            height: AppSizes.keypadKey,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: AppSizes.iconLg, color: p.text)
                  : Text(
                      label!,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
