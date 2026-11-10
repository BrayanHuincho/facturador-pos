import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/preferencias/vista_productos.dart';
import '../../../core/router/rutas.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../data/catalogo_repository.dart';
import '../domain/catalogo_models.dart';
import 'categorias_screen.dart';
import 'producto_form_screen.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  static const _esperaBusqueda = Duration(milliseconds: 300);

  Timer? _temporizador;
  String _termino = '';
  int _pestana = 0;
  String? _categoria;

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  void _alBuscar(String texto) {
    _temporizador?.cancel();
    _temporizador = Timer(_esperaBusqueda, () {
      if (mounted) setState(() => _termino = texto.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = ref.watch(rolActualProvider) == RolUsuario.admin;
    final p = context.palette;
    final enProductos = _pestana == 0;
    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Productos',
            automaticBack: false,
            actions: [
              if (enProductos) const AccionVistaProductos(),
              if (esAdmin)
                AppHeaderAction(
                  icon: LucideIcons.plus,
                  tooltip: enProductos ? 'Nuevo producto' : 'Nueva categoría',
                  label: 'Crear',
                  onPressed: () async {
                    if (!enProductos) {
                      await CategoriasLista.editar(context);
                      return;
                    }
                    await context.push(Rutas.producto(idProductoNuevo));
                    ref.invalidate(productosProvider);
                  },
                ),
            ],
            bottom: enProductos
                ? AppSearchField.onBrand(
                    hint: 'Buscar por nombre o código',
                    onChanged: _alBuscar,
                  )
                : null,
          ),
          ColoredBox(
            color: p.surface,
            child: AppTabs(
              tabs: const ['Productos', 'Categorías'],
              index: _pestana,
              onChanged: (i) => setState(() => _pestana = i),
            ),
          ),
          Expanded(
            child: enProductos
                ? _listaProductos(esAdmin)
                : CategoriasLista(editable: esAdmin),
          ),
        ],
      ),
    );
  }

  Widget _listaProductos(bool esAdmin) {
    final productos = ref.watch(productosProvider(_termino));
    final categorias =
        ref.watch(categoriasProvider).value ?? const <Categoria>[];
    final enGrilla = ref.watch(productosEnGrillaProvider);
    final porId = {for (final c in categorias) c.id: c};
    return ContenidoAsync<List<Producto>>(
      valor: productos,
      onReintentar: () => ref.invalidate(productosProvider),
      builder: (filas) {
        final permitidos = esAdmin
            ? filas
            : filas.where((p) => p.activo).toList();
        if (permitidos.isEmpty) {
          return const EstadoVacio(
            titulo: 'Aún no hay productos',
            icono: LucideIcons.package,
          );
        }
        final cuenta = <String?, int>{};
        for (final producto in permitidos) {
          cuenta[producto.categoriaId] =
              (cuenta[producto.categoriaId] ?? 0) + 1;
        }
        final visibles = _categoria == null
            ? permitidos
            : permitidos.where((p) => p.categoriaId == _categoria).toList();
        Future<void> abrir(Producto producto) async {
          await context.push(Rutas.producto(producto.id));
          ref.invalidate(productosProvider);
        }

        const margen = EdgeInsets.fromLTRB(
          AppSpace.x4,
          AppSpace.x3,
          AppSpace.x4,
          AppSpace.x6,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (categorias.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.x3),
                child: CategoryChips<String>(
                  items: [
                    CategoryChipItem(
                      id: null,
                      label: 'Todo',
                      count: permitidos.length,
                    ),
                    for (final c in categorias)
                      if ((cuenta[c.id] ?? 0) > 0)
                        CategoryChipItem(
                          id: c.id,
                          label: c.nombre,
                          count: cuenta[c.id],
                        ),
                  ],
                  selected: _categoria,
                  onSelected: (id) =>
                      setState(() => _categoria = id == _categoria ? null : id),
                ),
              ),
            Expanded(
              child: enGrilla
                  ? GrillaProductos(
                      padding: margen,
                      itemCount: visibles.length,
                      itemBuilder: (_, indice) {
                        final producto = visibles[indice];
                        final ruta = producto.imagenPath;
                        return TarjetaProducto(
                          nombre: producto.nombre,
                          categoria: porId[producto.categoriaId]?.nombre,
                          subtitulo: producto.codigo,
                          atenuado: !producto.activo,
                          imagenUrl: ruta == null
                              ? null
                              : ref
                                    .read(catalogoRepositoryProvider)
                                    .urlImagen(ruta),
                          precio: MoneyText(
                            producto.precio,
                            size: MoneySize.small,
                          ),
                          pie: const SizedBox.shrink(),
                          alTocar: () => abrir(producto),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: margen,
                      itemCount: visibles.length + 1,
                      itemBuilder: (_, indice) {
                        if (indice == visibles.length) {
                          return filas.length == limiteResultadosCatalogo
                              ? const Padding(
                                  padding: EdgeInsets.all(AppSpace.x4),
                                  child: Text(
                                    'Hay más resultados. Afina la búsqueda.',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : const SizedBox.shrink();
                        }
                        final producto = visibles[indice];
                        return _FilaProducto(
                          producto: producto,
                          categoria: porId[producto.categoriaId]?.nombre,
                          onTap: () => abrir(producto),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FilaProducto extends ConsumerWidget {
  const _FilaProducto({
    required this.producto,
    required this.categoria,
    required this.onTap,
  });

  final Producto producto;
  final String? categoria;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagen = producto.imagenPath;
    final p = context.palette;
    final detalle = [
      ?producto.codigo,
      if (!producto.activo) 'Inactivo',
    ].join(' · ');
    return ListCard(
      margin: const EdgeInsets.only(bottom: AppSpace.x2 + 2),
      onTap: onTap,
      dimmed: !producto.activo,
      leading: ProductThumb(
        nombre: producto.nombre,
        dimmed: !producto.activo,
        categoria: categoria,
        imagenUrl: imagen == null
            ? null
            : ref.read(catalogoRepositoryProvider).urlImagen(imagen),
      ),
      title: producto.nombre,
      subtitle: detalle.isEmpty ? null : detalle,
      trailing: MoneyText(
        producto.precio,
        color: producto.activo ? p.text : p.textMuted,
      ),
    );
  }
}
