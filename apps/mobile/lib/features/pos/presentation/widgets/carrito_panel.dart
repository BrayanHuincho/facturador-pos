import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/carrito.dart';
import '../../domain/catalogo_pos.dart';
import '../../domain/dinero.dart';
import '../pos_providers.dart';
import 'producto_card.dart';

class CarritoPanel extends ConsumerWidget {
  const CarritoPanel({required this.onCobrar, this.enHoja = false, super.key});

  final VoidCallback onCobrar;
  final bool enHoja;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);
    final fiscal =
        ref.watch(catalogoProvider).value?.fiscal ??
        ConfiguracionFiscal.porDefecto();
    final totales = carrito.totales(fiscal);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final n = carrito.lineas.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (enHoja)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpace.x2),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: AppRadii.pillAll,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.x4,
            AppSpace.x2,
            AppSpace.x2,
            AppSpace.x1,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Pedido'),
                      if (n > 0)
                        TextSpan(
                          text: ' · $n ${n == 1 ? 'producto' : 'productos'}',
                          style: TextStyle(
                            color: p.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (!carrito.vacio)
                TextButton.icon(
                  onPressed: ref.read(carritoProvider.notifier).limpiar,
                  icon: Icon(LucideIcons.trash2, size: 16, color: p.danger),
                  label: Text(
                    'Vaciar',
                    style: t.labelLarge?.copyWith(color: p.danger),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: carrito.vacio
              ? const EmptyState(
                  icon: LucideIcons.shoppingBag,
                  title: 'Pedido vacío',
                  message: 'Agrega productos para vender.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.x4,
                    vertical: AppSpace.x2,
                  ),
                  itemCount: n,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpace.x2),
                  itemBuilder: (_, i) => _FilaLinea(linea: carrito.lineas[i]),
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (totales.descuento > Decimal.zero)
                    Text(
                      'Descuento: ${soles(totales.descuento)}',
                      textAlign: TextAlign.end,
                      style: t.bodySmall?.copyWith(color: p.textMuted),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: t.titleMedium),
                      MoneyText(totales.total, size: MoneySize.large),
                    ],
                  ),
                  const SizedBox(height: AppSpace.x3),
                  AppButton(
                    label: 'Cobrar',
                    icon: LucideIcons.check,
                    size: AppButtonSize.large,
                    expand: true,
                    onPressed: carrito.vacio ? null : onCobrar,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaLinea extends ConsumerWidget {
  const _FilaLinea({required this.linea});

  final LineaCarrito linea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(carritoProvider.notifier);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final id = linea.producto.id;
    return ListCard(
      onTap: () => _editarDescuento(context, ref),
      title: linea.producto.nombre,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoneyText(linea.importeNeto, size: MoneySize.small, color: p.text),
          Text(
            linea.descuento > Decimal.zero
                ? 'Descuento ${soles(linea.descuento)}'
                : 'Agregar descuento',
            style: t.bodySmall?.copyWith(color: p.brand),
          ),
        ],
      ),
      trailing: StepperCompacto(
        valor: linea.cantidad,
        alCambiar: (n) => notifier.fijarCantidad(id, n),
        alTocarValor: () => _editarCantidad(context, ref),
      ),
    );
  }

  Future<void> _editarCantidad(BuildContext context, WidgetRef ref) async {
    final valor = await showDialog<Decimal>(
      context: context,
      builder: (_) => _DialogoNumero(
        titulo: 'Cantidad',
        inicial: cantidadLegible(linea.cantidad),
      ),
    );
    if (valor != null) {
      ref
          .read(carritoProvider.notifier)
          .fijarCantidad(linea.producto.id, valor);
    }
  }

  Future<void> _editarDescuento(BuildContext context, WidgetRef ref) async {
    final valor = await showDialog<Decimal>(
      context: context,
      builder: (_) => _DialogoDescuento(linea: linea),
    );
    if (valor != null) {
      ref
          .read(carritoProvider.notifier)
          .fijarDescuento(linea.producto.id, valor);
    }
  }
}

class _DialogoNumero extends StatefulWidget {
  const _DialogoNumero({required this.titulo, required this.inicial});

  final String titulo;
  final String inicial;

  @override
  State<_DialogoNumero> createState() => _DialogoNumeroState();
}

class _DialogoNumeroState extends State<_DialogoNumero> {
  late final _control = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _aceptar() {
    final valor = decimalDeEntrada(_control.text);
    if (valor != null && valor >= cero) Navigator.of(context).pop(valor);
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(widget.titulo),
    content: TextField(
      controller: _control,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onSubmitted: (_) => _aceptar(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _aceptar, child: const Text('Aceptar')),
    ],
  );
}

class _DialogoDescuento extends StatefulWidget {
  const _DialogoDescuento({required this.linea});

  final LineaCarrito linea;

  @override
  State<_DialogoDescuento> createState() => _DialogoDescuentoState();
}

class _DialogoDescuentoState extends State<_DialogoDescuento> {
  late final _control = TextEditingController(
    text: widget.linea.descuento > cero ? importe(widget.linea.descuento) : '',
  );
  bool _porcentaje = false;
  String? _error;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _aceptar() {
    final valor = _control.text.trim().isEmpty
        ? cero
        : decimalDeEntrada(_control.text);
    if (valor == null || valor < cero) {
      setState(() => _error = 'Monto no válido');
      return;
    }
    final monto = _porcentaje
        ? redondear2(dividir(widget.linea.bruto * valor, cien))
        : redondear2(valor);
    if (monto > widget.linea.bruto) {
      setState(
        () => _error = 'Supera el importe de ${soles(widget.linea.bruto)}',
      );
      return;
    }
    Navigator.of(context).pop(monto);
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: const Text('Descuento'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('S/')),
            ButtonSegment(value: true, label: Text('%')),
          ],
          selected: {_porcentaje},
          onSelectionChanged: (s) => setState(() => _porcentaje = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _control,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(errorText: _error),
          onSubmitted: (_) => _aceptar(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _aceptar, child: const Text('Aceptar')),
    ],
  );
}
