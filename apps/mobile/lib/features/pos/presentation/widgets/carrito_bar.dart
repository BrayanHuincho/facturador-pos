import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/catalogo_pos.dart';
import '../../domain/dinero.dart';
import '../pos_providers.dart';

class CarritoBar extends ConsumerWidget {
  const CarritoBar({required this.alAbrir, super.key});

  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);
    final fiscal =
        ref.watch(catalogoProvider).value?.fiscal ??
        ConfiguracionFiscal.porDefecto();
    final total = carrito.totales(fiscal).total;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final unidades = cantidadLegible(carrito.unidades);
    final items =
        '$unidades ${carrito.unidades == Decimal.one ? 'ítem' : 'ítems'}';
    final visible = !carrito.vacio;

    return AnimatedSlide(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      offset: visible ? Offset.zero : const Offset(0, 1.5),
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x3),
            child: Semantics(
              button: true,
              label: 'Ver pedido, $items',
              child: Material(
                color: p.header,
                elevation: 3,
                shadowColor: p.header.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: alAbrir,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 60),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.x3,
                        AppSpace.x2,
                        AppSpace.x3,
                        AppSpace.x2,
                      ),
                      child: Row(
                        children: [
                          _Bolsa(unidades: unidades),
                          const SizedBox(width: AppSpace.x3),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ver pedido',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.titleSmall?.copyWith(
                                    color: p.onHeader,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  items,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodySmall?.copyWith(
                                    color: p.onHeader.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.x2),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: MoneyText(
                                  total,
                                  color: p.onHeader,
                                  size: MoneySize.large,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.x1),
                          Icon(
                            LucideIcons.chevronRight,
                            color: p.onHeader,
                            size: AppSizes.iconMd,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bolsa extends StatelessWidget {
  const _Bolsa({required this.unidades});

  final String unidades;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox.square(
      dimension: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.onHeader.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppV2.iconChipRadius),
              ),
              child: Icon(LucideIcons.shoppingBag, color: p.onHeader, size: 22),
            ),
          ),
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.onHeader,
                borderRadius: AppRadii.pillAll,
                border: Border.all(color: p.header, width: 2),
              ),
              child: Text(
                unidades,
                style: TextStyle(
                  color: p.header,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
