import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_client.dart';
import '../../../core/formatos/formatos.dart';
import '../../../core/formatos/validadores.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../data/catalogo_repository.dart';
import '../domain/catalogo_models.dart';
import 'escaner_screen.dart';

const String idProductoNuevo = 'nuevo';

final _formatoSeisDecimales = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d{0,6}'),
);
final _formatoCuatroDecimales = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d{0,4}'),
);

String? _validarDecimalOpcional(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return null;
  return Decimal.tryParse(texto) == null ? 'Escribe un número válido' : null;
}

class ProductoFormScreen extends ConsumerWidget {
  const ProductoFormScreen({required this.productoId, super.key});

  final String? productoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = productoId;
    final esAdmin = ref.watch(rolActualProvider) == RolUsuario.admin;
    if (id == null) {
      return Scaffold(
        body: Column(
          children: [
            const AppHeader(title: 'Nuevo producto'),
            Expanded(
              child: esAdmin
                  ? const _FormularioProducto(producto: null, editable: true)
                  : const EstadoVacio(
                      titulo: 'Sin permiso',
                      mensaje: 'Solo un administrador puede crear productos.',
                    ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          AppHeader(title: esAdmin ? 'Editar producto' : 'Producto'),
          Expanded(
            child: ContenidoAsync<Producto>(
              valor: ref.watch(productoProvider(id)),
              onReintentar: () => ref.invalidate(productoProvider(id)),
              builder: (producto) =>
                  _FormularioProducto(producto: producto, editable: esAdmin),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormularioProducto extends ConsumerStatefulWidget {
  const _FormularioProducto({required this.producto, required this.editable});

  final Producto? producto;
  final bool editable;

  @override
  ConsumerState<_FormularioProducto> createState() =>
      _FormularioProductoState();
}

class _FormularioProductoState extends ConsumerState<_FormularioProducto> {
  final _formulario = GlobalKey<FormState>();
  late final Producto? _base = widget.producto;
  late final _nombre = TextEditingController(text: _base?.nombre);
  late final _codigo = TextEditingController(text: _base?.codigo);
  late final _barras = TextEditingController(text: _base?.codigoBarras);
  late final _descripcion = TextEditingController(text: _base?.descripcion);
  late final _unidad = TextEditingController(text: _base?.unidad ?? 'NIU');
  late final _precio = TextEditingController(text: _base?.precio.toString());
  late final _costo = TextEditingController(text: _base?.costo?.toString());
  late final _stockMinimo = TextEditingController(
    text: _base?.stockMinimo?.toString(),
  );
  late String? _categoriaId = _base?.categoriaId;
  late String _afectacion = _base?.afectacion ?? '10';
  late bool _aplicaIcbper = _base?.aplicaIcbper ?? false;
  late bool _controlaStock = _base?.controlaStock ?? false;
  late bool _activo = _base?.activo ?? true;
  late String? _imagenPath = _base?.imagenPath;
  bool _guardando = false;
  bool _subiendoImagen = false;

  @override
  void dispose() {
    for (final controlador in [
      _nombre,
      _codigo,
      _barras,
      _descripcion,
      _unidad,
      _precio,
      _costo,
      _stockMinimo,
    ]) {
      controlador.dispose();
    }
    super.dispose();
  }

  String? _textoONulo(TextEditingController controlador) {
    final texto = controlador.text.trim();
    return texto.isEmpty ? null : texto;
  }

  Future<void> _escanear() async {
    final codigo = await EscanerScreen.abrir(context);
    if (codigo != null && mounted) setState(() => _barras.text = codigo);
  }

  Future<void> _elegirImagen() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(hoja).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.images),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(hoja).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;
    final imagen = await ImagePicker().pickImage(
      source: origen,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (imagen == null || !mounted) return;
    setState(() => _subiendoImagen = true);
    try {
      final ruta = await ref
          .read(catalogoRepositoryProvider)
          .subirImagenProducto(
            contenido: await imagen.readAsBytes(),
            nombreArchivo: imagen.name,
          );
      if (mounted) setState(() => _imagenPath = ruta);
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, mensajeDeEscritura(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _subiendoImagen = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);
    final base = _base;
    try {
      final id = await ref.read(catalogoRepositoryProvider).guardarProducto(
        base?.id,
        {
          'nombre': _nombre.text.trim(),
          'codigo': _textoONulo(_codigo),
          'codigo_barras': _textoONulo(_barras),
          'descripcion': _textoONulo(_descripcion),
          'categoria_id': _categoriaId,
          'unidad': _unidad.text.trim().toUpperCase(),
          'precio': _precio.text.trim(),
          'costo': _textoONulo(_costo),
          'afectacion': _afectacion,
          'aplica_icbper': _aplicaIcbper,
          'controla_stock': _controlaStock,
          'stock_minimo': _controlaStock ? _textoONulo(_stockMinimo) : null,
          'imagen_path': _imagenPath,
          'activo': _activo,
        },
      );
      ref.invalidate(productoProvider(id));
      ref.invalidate(productosProvider);
      if (mounted) {
        mostrarMensaje(context, 'Producto guardado.');
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, mensajeDeEscritura(error), error: true);
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = widget.editable;
    final imagen = _imagenPath;
    final categorias =
        ref.watch(categoriasProvider).value ?? const <Categoria>[];
    final opcionesCategoria = categorias
        .where((c) => c.activa || c.id == _categoriaId)
        .toList();
    final categoriaValida = opcionesCategoria.any((c) => c.id == _categoriaId)
        ? _categoriaId
        : null;
    const separacion = SizedBox(height: AppSpace.x3);
    final base = _base;
    final p = context.palette;
    final textos = Theme.of(context).textTheme;
    return Form(
      key: _formulario,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.x4),
              children: [
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: p.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppV2.cardRadius),
                      border: Border.all(color: p.border),
                    ),
                    child: imagen == null
                        ? Icon(
                            LucideIcons.package,
                            size: 40,
                            color: p.textMuted,
                          )
                        : Image.network(
                            ref
                                .read(catalogoRepositoryProvider)
                                .urlImagen(imagen),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              LucideIcons.imageOff,
                              size: 40,
                              color: p.textMuted,
                            ),
                          ),
                  ),
                ),
                if (editable) ...[
                  separacion,
                  BotonSecundario(
                    texto: imagen == null ? 'Agregar imagen' : 'Cambiar imagen',
                    icono: LucideIcons.camera,
                    cargando: _subiendoImagen,
                    onPressed: _elegirImagen,
                  ),
                ],
                const SizedBox(height: AppSpace.x4),
                SectionCard(
                  title: 'Datos generales',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CampoTexto(
                        etiqueta: 'Nombre',
                        controller: _nombre,
                        habilitado: editable,
                        validator: validarRequerido,
                      ),
                      separacion,
                      CampoTexto(
                        etiqueta: 'Código',
                        controller: _codigo,
                        habilitado: editable,
                      ),
                      separacion,
                      CampoTexto(
                        etiqueta: 'Código de barras',
                        controller: _barras,
                        habilitado: editable,
                        sufijo: editable
                            ? IconButton(
                                tooltip: 'Escanear',
                                icon: const Icon(LucideIcons.scanLine),
                                onPressed: _escanear,
                              )
                            : null,
                      ),
                      separacion,
                      Text(
                        'Categoría',
                        style: textos.labelMedium?.copyWith(color: p.text),
                      ),
                      const SizedBox(height: AppSpace.x1 + 2),
                      AppSelectorField<String?>(
                        titulo: 'Categoría',
                        icono: LucideIcons.tags,
                        key: ValueKey('categoria-${opcionesCategoria.length}'),
                        initialValue: categoriaValida,
                        opciones: [
                          const AppSelectorOption<String?>(
                            value: null,
                            label: 'Sin categoría',
                          ),
                          for (final categoria in opcionesCategoria)
                            AppSelectorOption(
                              value: categoria.id,
                              label: categoria.nombre,
                            ),
                        ],
                        onChanged: editable
                            ? (valor) => setState(() => _categoriaId = valor)
                            : null,
                      ),
                      separacion,
                      CampoTexto(
                        etiqueta: 'Descripción',
                        controller: _descripcion,
                        habilitado: editable,
                        lineas: 2,
                      ),
                    ],
                  ),
                ),
                separacion,
                SectionCard(
                  title: 'Precio e impuestos',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CampoTexto(
                        etiqueta: 'Precio de venta',
                        controller: _precio,
                        habilitado: editable,
                        teclado: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        formateadores: [_formatoSeisDecimales],
                        ayuda: 'Incluye IGV cuando corresponde.',
                        validator: (valor) =>
                            Decimal.tryParse(valor?.trim() ?? '') == null
                            ? 'Escribe el precio'
                            : null,
                      ),
                      separacion,
                      CampoTexto(
                        etiqueta: 'Costo',
                        controller: _costo,
                        habilitado: editable,
                        teclado: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        formateadores: [_formatoSeisDecimales],
                        validator: _validarDecimalOpcional,
                      ),
                      separacion,
                      CampoTexto(
                        etiqueta: 'Unidad SUNAT',
                        controller: _unidad,
                        habilitado: editable,
                        capitalizacion: TextCapitalization.characters,
                        ayuda: 'NIU para bienes, ZZ para servicios.',
                        validator: validarRequerido,
                      ),
                      separacion,
                      Text(
                        'Afectación IGV',
                        style: textos.labelMedium?.copyWith(color: p.text),
                      ),
                      const SizedBox(height: AppSpace.x1 + 2),
                      AppSelectorField<String>(
                        titulo: 'Afectación IGV',
                        icono: LucideIcons.percent,
                        initialValue: _afectacion,
                        opciones: [
                          for (final opcion in afectacionesIgv.entries)
                            AppSelectorOption(
                              value: opcion.key,
                              label: opcion.value,
                            ),
                        ],
                        onChanged: editable
                            ? (valor) {
                                if (valor != null) {
                                  setState(() => _afectacion = valor);
                                }
                              }
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aplica ICBPER'),
                        subtitle: const Text(
                          'Impuesto a las bolsas de plástico',
                        ),
                        value: _aplicaIcbper,
                        onChanged: editable
                            ? (valor) => setState(() => _aplicaIcbper = valor)
                            : null,
                      ),
                    ],
                  ),
                ),
                separacion,
                SectionCard(
                  title: 'Inventario y estado',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Controlar stock'),
                        value: _controlaStock,
                        onChanged: editable
                            ? (valor) => setState(() => _controlaStock = valor)
                            : null,
                      ),
                      if (_controlaStock) ...[
                        CampoTexto(
                          etiqueta: 'Stock mínimo',
                          controller: _stockMinimo,
                          habilitado: editable,
                          teclado: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          formateadores: [_formatoCuatroDecimales],
                          validator: _validarDecimalOpcional,
                        ),
                        separacion,
                      ],
                      if (base != null)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Producto activo'),
                          value: _activo,
                          onChanged: editable
                              ? (valor) => setState(() => _activo = valor)
                              : null,
                        ),
                    ],
                  ),
                ),
                if (base != null && base.controlaStock) ...[
                  separacion,
                  _SeccionStock(producto: base, puedeAjustar: editable),
                ],
              ],
            ),
          ),
          if (editable)
            DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.x4),
                  child: BotonPrimario(
                    texto: 'Guardar',
                    cargando: _guardando,
                    onPressed: _subiendoImagen ? null : _guardar,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SeccionStock extends ConsumerWidget {
  const _SeccionStock({required this.producto, required this.puedeAjustar});

  final Producto producto;
  final bool puedeAjustar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minimo = producto.stockMinimo;
    return SectionCard(
      title: 'Stock',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContenidoAsync<List<StockLocal>>(
            valor: ref.watch(stockProductoProvider(producto.id)),
            onReintentar: () =>
                ref.invalidate(stockProductoProvider(producto.id)),
            builder: (locales) => Column(
              children: [
                for (final local in locales)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const IconChip(LucideIcons.warehouse),
                    title: Text(local.establecimientoNombre),
                    subtitle: minimo != null && local.cantidad <= minimo
                        ? Text(
                            'Stock bajo',
                            style: TextStyle(color: context.palette.warning),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatearCantidad(local.cantidad)),
                        if (puedeAjustar)
                          IconButton(
                            tooltip: 'Ajustar stock',
                            icon: const Icon(LucideIcons.slidersHorizontal),
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => _DialogoAjusteStock(
                                productoId: producto.id,
                                local: local,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogoAjusteStock extends ConsumerStatefulWidget {
  const _DialogoAjusteStock({required this.productoId, required this.local});

  final String productoId;
  final StockLocal local;

  @override
  ConsumerState<_DialogoAjusteStock> createState() =>
      _DialogoAjusteStockState();
}

class _DialogoAjusteStockState extends ConsumerState<_DialogoAjusteStock> {
  final _formulario = GlobalKey<FormState>();
  final _cantidad = TextEditingController();
  final _motivo = TextEditingController();
  bool _esEntrada = true;
  bool _guardando = false;

  @override
  void dispose() {
    _cantidad.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await ref
          .read(catalogoRepositoryProvider)
          .ajustarStock(
            productoId: widget.productoId,
            establecimientoId: widget.local.establecimientoId,
            cantidadConSigno:
                '${_esEntrada ? '' : '-'}${_cantidad.text.trim()}',
            motivo: _motivo.text.trim(),
          );
      ref.invalidate(stockProductoProvider(widget.productoId));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, mensajeDeError(error), error: true);
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text('Ajustar stock · ${widget.local.establecimientoNombre}'),
    content: Form(
      key: _formulario,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stock actual: ${formatearCantidad(widget.local.cantidad)}'),
            const SizedBox(height: AppSpace.x3),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Entrada')),
                ButtonSegment(value: false, label: Text('Salida')),
              ],
              selected: {_esEntrada},
              onSelectionChanged: (seleccion) =>
                  setState(() => _esEntrada = seleccion.first),
            ),
            const SizedBox(height: AppSpace.x3),
            CampoTexto(
              etiqueta: 'Cantidad',
              controller: _cantidad,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              formateadores: [_formatoCuatroDecimales],
              validator: (valor) {
                final cantidad = Decimal.tryParse(valor?.trim() ?? '');
                return cantidad == null || cantidad <= Decimal.zero
                    ? 'Escribe una cantidad mayor a cero'
                    : null;
              },
            ),
            const SizedBox(height: AppSpace.x3),
            CampoTexto(
              etiqueta: 'Motivo',
              controller: _motivo,
              longitudMaxima: 500,
              validator: validarRequerido,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _guardando ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: _guardando ? null : _guardar,
        child: const Text('Aplicar'),
      ),
    ],
  );
}
