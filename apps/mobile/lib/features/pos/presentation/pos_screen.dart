import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/preferencias/vista_productos.dart';
import '../../../core/router/rutas.dart';
import '../../../design_system/design_system.dart';
import '../../ajustes/presentation/banner_modo_prueba.dart';
import '../domain/catalogo_pos.dart';
import 'pos_providers.dart';
import 'widgets/carrito_bar.dart';
import 'widgets/carrito_panel.dart';
import 'widgets/cola_sheet.dart';
import 'widgets/producto_card.dart';
import 'widgets/scanner_page.dart';

const _anchoPanelCarrito = 380.0;
const _huecoCarrito = 96.0;

int _columnasPara(double ancho) => ancho >= 600 ? 2 : 1;

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _busqueda = TextEditingController();
  final _foco = FocusNode();

  @override
  void dispose() {
    _busqueda.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _agregarPorCodigo(String codigo, Catalogo catalogo) {
    final texto = codigo.trim();
    if (texto.isEmpty) return;
    for (final producto in catalogo.productos) {
      if (producto.tieneCodigo(texto)) {
        ref.read(carritoProvider.notifier).agregar(producto);
        _busqueda.clear();
        ref.read(consultaProductoProvider.notifier).fijar('');
        _foco.requestFocus();
        return;
      }
    }
    AppToast.error(context, 'No hay un producto con el código $texto.');
  }

  Future<void> _escanear(Catalogo catalogo) async {
    final codigo = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScannerPage()));
    if (codigo != null && mounted) _agregarPorCodigo(codigo, catalogo);
  }

  void _abrirCarrito() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: CarritoPanel(onCobrar: _irACobro, enHoja: true),
      ),
    );
  }

  void _irACobro() {
    final raiz = Navigator.of(context, rootNavigator: true);
    if (raiz.canPop()) raiz.pop();
    context.push(Rutas.posCobro);
  }

  void _vaciar() {
    final carrito = ref.read(carritoProvider.notifier);
    final previo = ref.read(carritoProvider);
    carrito.limpiar();
    AppToast.exito(
      context,
      'Pedido vaciado',
      accion: ToastAccion('Deshacer', () => carrito.restaurar(previo)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sincronizadorColaProvider);
    final catalogo = ref.watch(catalogoProvider);
    final pendientes = ref.watch(entradasColaProvider).value?.length ?? 0;
    final vacio = ref.watch(carritoProvider.select((c) => c.vacio));
    final p = context.palette;
    final datos = catalogo.value;
    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Nueva venta',
            automaticBack: false,
            actions: [
              if (!vacio)
                AppHeaderAction(
                  icon: LucideIcons.trash2,
                  tooltip: 'Vaciar pedido',
                  label: 'Vaciar',
                  onPressed: _vaciar,
                ),
              IconButton(
                tooltip: 'Ventas en cola',
                color: p.onHeader,
                onPressed: () => mostrarColaSheet(context),
                icon: Badge(
                  isLabelVisible: pendientes > 0,
                  label: Text('$pendientes'),
                  child: const Icon(LucideIcons.cloudUpload),
                ),
              ),
              const AccionVistaProductos(),
              if (datos != null)
                AppHeaderAction(
                  icon: LucideIcons.scanLine,
                  tooltip: 'Escanear código',
                  onPressed: () => _escanear(datos),
                ),
            ],
            bottom: AppSearchField.onBrand(
              controller: _busqueda,
              focusNode: _foco,
              hint: 'Buscar producto',
              onChanged: ref.read(consultaProductoProvider.notifier).fijar,
              onSubmitted: datos == null
                  ? null
                  : (codigo) => _agregarPorCodigo(codigo, datos),
            ),
          ),
          const BannerModoPrueba(),
          Expanded(
            child: catalogo.when(
              loading: () => const _ListaSkeleton(),
              error: (error, _) => ErrorView(
                error: 'No se pudo cargar el catálogo.',
                onRetry: () => ref.invalidate(catalogoProvider),
              ),
              data: (cargado) => LayoutBuilder(
                builder: (context, restricciones) {
                  if (restricciones.maxWidth >= AppBreakpoints.expanded) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Catalogo(
                            catalogo: cargado,
                            huecoInferior: AppSpace.x4,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            0,
                            AppSpace.x4,
                            AppSpace.x4,
                            AppSpace.x4,
                          ),
                          child: SizedBox(
                            width: _anchoPanelCarrito,
                            child: DecoratedBox(
                              decoration: v2CardDecoration(p),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppV2.cardRadius,
                                ),
                                child: CarritoPanel(onCobrar: _irACobro),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: _Catalogo(
                          catalogo: cargado,
                          huecoInferior: _huecoCarrito,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: CarritoBar(alAbrir: _abrirCarrito),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Catalogo extends ConsumerWidget {
  const _Catalogo({required this.catalogo, required this.huecoInferior});

  final Catalogo catalogo;
  final double huecoInferior;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final consulta = ref.watch(consultaProductoProvider);
    final categoria = ref.watch(categoriaSeleccionadaProvider);
    final porId = {for (final c in catalogo.categorias) c.id: c};
    final cuenta = <String?, int>{};
    for (final producto in catalogo.productos) {
      cuenta[producto.categoriaId] = (cuenta[producto.categoriaId] ?? 0) + 1;
    }
    final productos = [
      for (final producto in catalogo.productos)
        if ((categoria == null || producto.categoriaId == categoria) &&
            producto.coincide(consulta))
          producto,
    ];
    Widget fila(ProductoPos producto) => ProductoFila(
      key: ValueKey(producto.id),
      producto: producto,
      categoria: porId[producto.categoriaId],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (catalogo.desdeCache)
          ColoredBox(
            color: p.warningSoft,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x2),
              child: Text(
                'Sin conexión: catálogo guardado. Las ventas se enviarán al volver la red.',
                textAlign: TextAlign.center,
                style: t.labelMedium?.copyWith(color: p.warning),
              ),
            ),
          ),
        if (catalogo.categorias.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.x3),
            child: CategoryChips<String>(
              items: [
                CategoryChipItem(
                  id: null,
                  label: 'Todo',
                  count: catalogo.productos.length,
                ),
                for (final c in catalogo.categorias)
                  if ((cuenta[c.id] ?? 0) > 0)
                    CategoryChipItem(
                      id: c.id,
                      label: c.nombre,
                      count: cuenta[c.id],
                    ),
              ],
              selected: categoria,
              onSelected: (id) => ref
                  .read(categoriaSeleccionadaProvider.notifier)
                  .fijar(id == categoria ? null : id),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.x4,
            AppSpace.x3,
            AppSpace.x4,
            AppSpace.x2,
          ),
          child: Text(
            '${productos.length} ${productos.length == 1 ? 'producto' : 'productos'}',
            style: t.labelMedium?.copyWith(color: p.textMuted),
          ),
        ),
        Expanded(
          child: productos.isEmpty
              ? EmptyState(
                  icon: LucideIcons.search,
                  title: consulta.isNotEmpty || categoria != null
                      ? 'Sin resultados'
                      : 'Aún no hay productos',
                  message: consulta.isNotEmpty || categoria != null
                      ? 'Prueba con otra palabra o categoría.'
                      : 'Agrégalos desde Productos.',
                )
              : ref.watch(productosEnGrillaProvider)
              ? GrillaProductos(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.x4,
                    0,
                    AppSpace.x4,
                    huecoInferior,
                  ),
                  itemCount: productos.length,
                  itemBuilder: (_, indice) => ProductoTarjetaVenta(
                    key: ValueKey(productos[indice].id),
                    producto: productos[indice],
                    categoria: porId[productos[indice].categoriaId],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, restricciones) {
                    final columnas = _columnasPara(restricciones.maxWidth);
                    final filas = (productos.length / columnas).ceil();
                    return RefreshIndicator(
                      onRefresh: () => ref.refresh(catalogoProvider.future),
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          AppSpace.x4,
                          0,
                          AppSpace.x4,
                          huecoInferior,
                        ),
                        itemCount: filas,
                        itemBuilder: (_, indice) {
                          final Widget contenido;
                          if (columnas == 1) {
                            contenido = fila(productos[indice]);
                          } else {
                            final primero = indice * 2;
                            contenido = IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: fila(productos[primero])),
                                  const SizedBox(width: AppSpace.x3),
                                  Expanded(
                                    child: primero + 1 < productos.length
                                        ? fila(productos[primero + 1])
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpace.x2 + 2,
                            ),
                            child: contenido,
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ListaSkeleton extends StatelessWidget {
  const _ListaSkeleton();

  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.x4,
        AppSpace.x3,
        AppSpace.x4,
        0,
      ),
      itemCount: 9,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpace.x2 + 2),
        child: SkeletonBox(height: 72, radius: AppV2.cardRadius),
      ),
    ),
  );
}
