import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/preferencias/vista_productos.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/catalogo_pos.dart';
import '../../domain/dinero.dart';
import '../pos_providers.dart';
import 'cantidad_sheet.dart';

class ProductoFila extends ConsumerWidget {
  const ProductoFila({required this.producto, this.categoria, super.key});

  final ProductoPos producto;
  final CategoriaPos? categoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cantidad = ref.watch(
      carritoProvider.select((c) => c.cantidadDe(producto.id)),
    );
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final carrito = ref.read(carritoProvider.notifier);

    void sumar() {
      HapticFeedback.lightImpact();
      carrito.agregar(producto);
    }

    return RepaintBoundary(
      child: ListCard(
        dimmed: producto.sinStock,
        leading: ProductThumb(
          nombre: producto.nombre,
          categoria: categoria?.nombre,
          dimmed: producto.sinStock,
          imagenUrl: ref
              .read(catalogoRepositoryProvider)
              .urlImagen(producto.imagenPath),
        ),
        title: producto.nombre,
        subtitleWidget: Row(
          children: [
            if (producto.sinStock) ...[
              const _BadgeAgotado(),
              const SizedBox(width: AppSpace.x2),
            ],
            Flexible(
              child: Text(
                categoria?.nombre ?? 'Sin categoría',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(color: p.textMuted),
              ),
            ),
          ],
        ),
        onTap: sumar,
        onLongPress: () =>
            CantidadSheet.mostrarParaProducto(context, ref, producto),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MoneyText(producto.precio, color: p.text),
            const SizedBox(height: AppSpace.x1 + 2),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: cantidad == Decimal.zero
                  ? _Circulo(
                      key: const ValueKey('mas'),
                      color: p.brand,
                      icono: LucideIcons.plus,
                      iconColor: p.onBrand,
                      alTocar: sumar,
                    )
                  : StepperCompacto(
                      key: const ValueKey('stepper'),
                      valor: cantidad,
                      alCambiar: (n) => carrito.fijarCantidad(producto.id, n),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductoTarjetaVenta extends ConsumerWidget {
  const ProductoTarjetaVenta({
    required this.producto,
    this.categoria,
    super.key,
  });

  final ProductoPos producto;
  final CategoriaPos? categoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cantidad = ref.watch(
      carritoProvider.select((c) => c.cantidadDe(producto.id)),
    );
    final p = context.palette;
    final carrito = ref.read(carritoProvider.notifier);
    void sumar() {
      HapticFeedback.lightImpact();
      carrito.agregar(producto);
    }

    return TarjetaProducto(
      nombre: producto.nombre,
      categoria: categoria?.nombre,
      subtitulo: producto.sinStock ? 'Sin stock' : categoria?.nombre,
      atenuado: producto.sinStock,
      imagenUrl: ref
          .read(catalogoRepositoryProvider)
          .urlImagen(producto.imagenPath),
      alTocar: sumar,
      alMantener: () =>
          CantidadSheet.mostrarParaProducto(context, ref, producto),
      precio: MoneyText(producto.precio, size: MoneySize.small, color: p.text),
      pie: cantidad == Decimal.zero
          ? _Circulo(
              color: p.brand,
              icono: LucideIcons.plus,
              iconColor: p.onBrand,
              alTocar: sumar,
              tamano: 28,
            )
          : Container(
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.brand, shape: BoxShape.circle),
              child: Text(
                cantidadLegible(cantidad),
                style: TextStyle(
                  color: p.onBrand,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}

class _BadgeAgotado extends StatelessWidget {
  const _BadgeAgotado();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.dangerSoft,
        borderRadius: AppRadii.pillAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x2,
          vertical: 1,
        ),
        child: Text(
          'Sin stock',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: p.danger, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class StepperCompacto extends StatelessWidget {
  const StepperCompacto({
    required this.valor,
    required this.alCambiar,
    this.alTocarValor,
    super.key,
  });

  final Decimal valor;
  final ValueChanged<Decimal> alCambiar;
  final VoidCallback? alTocarValor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.brandSoft,
        borderRadius: AppRadii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Circulo(
            color: Colors.transparent,
            icono: valor <= Decimal.one
                ? LucideIcons.trash2
                : LucideIcons.minus,
            iconColor: p.brand,
            alTocar: () => alCambiar(valor - Decimal.one),
          ),
          GestureDetector(
            onTap: alTocarValor,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 30),
              child: Text(
                cantidadLegible(valor),
                textAlign: TextAlign.center,
                style: AppTypography.money(t.titleSmall!)
                    .copyWith(color: p.brand, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          _Circulo(
            color: p.brand,
            icono: LucideIcons.plus,
            iconColor: p.onBrand,
            alTocar: () => alCambiar(valor + Decimal.one),
          ),
        ],
      ),
    );
  }
}

class _Circulo extends StatelessWidget {
  const _Circulo({
    required this.color,
    required this.icono,
    required this.iconColor,
    required this.alTocar,
    this.tamano = 36,
    super.key,
  });

  final Color color;
  final IconData icono;
  final Color iconColor;
  final VoidCallback alTocar;
  final double tamano;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: tamano,
    child: Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          alTocar();
        },
        child: Icon(icono, size: tamano * 0.55, color: iconColor),
      ),
    ),
  );
}
