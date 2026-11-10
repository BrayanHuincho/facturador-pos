import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/design_system.dart';

const _claveGrilla = 'productos_en_grilla';

final productosEnGrillaProvider =
    NotifierProvider<ProductosEnGrillaNotifier, bool>(
      ProductosEnGrillaNotifier.new,
    );

class ProductosEnGrillaNotifier extends Notifier<bool> {
  @override
  bool build() {
    _cargar();
    return false;
  }

  Future<void> _cargar() async {
    final preferencias = await SharedPreferences.getInstance();
    state = preferencias.getBool(_claveGrilla) ?? false;
  }

  Future<void> alternar() async {
    state = !state;
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setBool(_claveGrilla, state);
  }
}

class AccionVistaProductos extends ConsumerWidget {
  const AccionVistaProductos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enGrilla = ref.watch(productosEnGrillaProvider);
    return AppHeaderAction(
      icon: enGrilla ? LucideIcons.list : LucideIcons.layoutGrid,
      tooltip: enGrilla ? 'Ver en lista' : 'Ver en cuadrícula',
      onPressed: ref.read(productosEnGrillaProvider.notifier).alternar,
    );
  }
}

class GrillaProductos extends StatelessWidget {
  const GrillaProductos({
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: padding,
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 124,
      mainAxisSpacing: AppSpace.x2,
      crossAxisSpacing: AppSpace.x2,
      mainAxisExtent: 172,
    ),
    itemCount: itemCount,
    itemBuilder: itemBuilder,
  );
}

class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({
    required this.nombre,
    required this.precio,
    required this.pie,
    this.categoria,
    this.imagenUrl,
    this.subtitulo,
    this.atenuado = false,
    this.alTocar,
    this.alMantener,
    super.key,
  });

  final String nombre;
  final Widget precio;
  final Widget pie;
  final String? categoria;
  final String? imagenUrl;
  final String? subtitulo;
  final bool atenuado;
  final VoidCallback? alTocar;
  final VoidCallback? alMantener;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final radio = BorderRadius.circular(AppV2.cardRadius);
    return DecoratedBox(
      decoration: v2CardDecoration(p),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radio,
          onTap: alTocar,
          onLongPress: alMantener,
          child: Opacity(
            opacity: atenuado ? 0.55 : 1,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ProductThumb(
                      nombre: nombre,
                      categoria: categoria,
                      imagenUrl: imagenUrl,
                      dimmed: atenuado,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: AppSpace.x1 + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        if (subtitulo != null)
                          Text(
                            subtitulo!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelSmall?.copyWith(color: p.textMuted),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: precio,
                        ),
                      ),
                      pie,
                    ],
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
