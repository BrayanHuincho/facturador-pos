import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/catalogo_pos.dart';
import '../../domain/dinero.dart';
import '../pos_providers.dart';

class CantidadSheet extends StatefulWidget {
  const CantidadSheet({
    required this.cantidadInicial,
    required this.alListo,
    super.key,
  });

  final Decimal cantidadInicial;
  final ValueChanged<Decimal> alListo;

  static Future<void> mostrarParaProducto(
    BuildContext context,
    WidgetRef ref,
    ProductoPos producto,
  ) => mostrar(
    context,
    titulo: producto.nombre,
    cantidadInicial: ref.read(carritoProvider).cantidadDe(producto.id),
    alListo: (cantidad) {
      final carrito = ref.read(carritoProvider.notifier);
      if (ref.read(carritoProvider).cantidadDe(producto.id) == cero) {
        if (cantidad > cero) carrito.agregar(producto);
      }
      carrito.fijarCantidad(producto.id, cantidad);
    },
  );

  static Future<void> mostrar(
    BuildContext context, {
    required String titulo,
    required Decimal cantidadInicial,
    required ValueChanged<Decimal> alListo,
  }) => AppBottomSheet.show<void>(
    context,
    title: titulo,
    child: Builder(
      builder: (hoja) => CantidadSheet(
        cantidadInicial: cantidadInicial,
        alListo: (valor) {
          Navigator.of(hoja).pop();
          alListo(valor);
        },
      ),
    ),
  );

  @override
  State<CantidadSheet> createState() => _CantidadSheetState();
}

class _CantidadSheetState extends State<CantidadSheet> {
  late final _cantidad =
      AmountInputController(maxDecimals: 4, maxIntegerDigits: 5)
        ..value = widget.cantidadInicial > cero
            ? cantidadLegible(widget.cantidadInicial)
            : '';
  bool _reemplazar = true;

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  void _tecla(KeypadKey tecla) {
    if (_reemplazar && tecla is DigitKey) _cantidad.clear();
    _reemplazar = false;
    _cantidad.press(tecla);
  }

  Decimal get _valor => _cantidad.amount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final habiaCantidad = widget.cantidadInicial > cero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: _cantidad,
          builder: (context, valor, _) => Text(
            valor.isEmpty ? '0' : valor,
            textAlign: TextAlign.center,
            style: AppTypography.totalDisplay.copyWith(
              color: valor.isEmpty ? p.textMuted : p.text,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.x3),
        NumericKeypad(onKey: _tecla, onClear: _cantidad.clear),
        const SizedBox(height: AppSpace.x4),
        ValueListenableBuilder<String>(
          valueListenable: _cantidad,
          builder: (context, _, _) {
            final quitar = _valor == cero && habiaCantidad;
            return AppButton(
              label: quitar ? 'Quitar del pedido' : 'Listo',
              size: AppButtonSize.large,
              expand: true,
              variant: quitar
                  ? AppButtonVariant.danger
                  : AppButtonVariant.primary,
              onPressed: _valor == cero && !habiaCantidad
                  ? null
                  : () => widget.alListo(_valor),
            );
          },
        ),
      ],
    );
  }
}
