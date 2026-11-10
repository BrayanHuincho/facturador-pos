import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/widgets.dart' hide EstadoVacio;
import '../data/comprobantes_repository.dart';
import '../domain/comprobante.dart';
import '../domain/importes.dart';
import 'widgets_documento.dart';

class NotaPage extends ConsumerWidget {
  const NotaPage({super.key, required this.id, required this.tipo});

  final String id;
  final String tipo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(comprobanteDetalleProvider(id));
    return Scaffold(
      body: Column(
        children: [
          AppHeader(title: tipo == '08' ? 'Nota de débito' : 'Nota de crédito'),
          Expanded(
            child: detalle.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EstadoVacio(mensaje: mensajeDeError(error)),
              data: (comprobante) =>
                  _FormularioNota(comprobante: comprobante, tipo: tipo),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineaNota {
  _LineaNota(this.item)
    : cantidad = TextEditingController(text: formatearCantidad(item.cantidad)),
      precio = TextEditingController(text: item.precioUnitario.toString());

  final ItemComprobante item;
  final TextEditingController cantidad;
  final TextEditingController precio;
  bool incluida = true;

  void liberar() {
    cantidad.dispose();
    precio.dispose();
  }

  Decimal? get importe {
    final c = decimalDeEntrada(cantidad.text);
    final p = decimalDeEntrada(precio.text);
    return c == null || p == null ? null : c * p;
  }
}

class _FormularioNota extends ConsumerStatefulWidget {
  const _FormularioNota({required this.comprobante, required this.tipo});

  final Comprobante comprobante;
  final String tipo;

  @override
  ConsumerState<_FormularioNota> createState() => _FormularioNotaState();
}

class _FormularioNotaState extends ConsumerState<_FormularioNota> {
  final _formulario = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  late final List<_LineaNota> _lineas = widget.comprobante.items
      .map(_LineaNota.new)
      .toList();
  late String _motivo = _motivos.keys.first;
  final String _claveIdempotencia = const Uuid().v4();
  bool _enviando = false;

  bool get _esCredito => widget.tipo == '07';
  Map<String, String> get _motivos =>
      _esCredito ? motivosNotaCredito : motivosNotaDebito;
  bool get _itemsBloqueados =>
      _esCredito && motivosCreditoTotales.contains(_motivo);

  @override
  void dispose() {
    _descripcion.dispose();
    for (final linea in _lineas) {
      linea.liberar();
    }
    super.dispose();
  }

  void _restaurarLineas() {
    for (final linea in _lineas) {
      linea.incluida = true;
      linea.cantidad.text = formatearCantidad(linea.item.cantidad);
      linea.precio.text = linea.item.precioUnitario.toString();
    }
  }

  Decimal get _totalEstimado => _lineas
      .where((l) => l.incluida)
      .fold(Decimal.zero, (suma, l) => suma + (l.importe ?? Decimal.zero));

  Future<void> _emitir() async {
    if (_enviando || !_formulario.currentState!.validate()) return;
    final incluidas = _lineas.where((l) => l.incluida).toList();
    if (incluidas.isEmpty) {
      avisar(context, 'Selecciona al menos un ítem');
      return;
    }
    setState(() => _enviando = true);
    try {
      await ref.read(comprobantesRepositoryProvider).emitirNota(
        _claveIdempotencia,
        {
          'tipo': widget.tipo,
          'afectado_id': widget.comprobante.id,
          'motivo_codigo': _motivo,
          'motivo_descripcion': _descripcion.text.trim().isEmpty
              ? _motivos[_motivo]
              : _descripcion.text.trim(),
          'items': [
            for (final linea in incluidas)
              {
                if (linea.item.productoId != null)
                  'producto_id': linea.item.productoId,
                if (linea.item.codigo != null) 'codigo': linea.item.codigo,
                'descripcion': linea.item.descripcion,
                'unidad': linea.item.unidad,
                'cantidad': decimalDeEntrada(linea.cantidad.text).toString(),
                'precio_unitario': decimalDeEntrada(linea.precio.text)
                    .toString(),
                if (linea.item.afectacion != null)
                  'afectacion': linea.item.afectacion,
              },
          ],
        },
      );
      if (!mounted) return;
      avisar(context, 'Nota emitida');
      context.pop();
    } catch (error) {
      if (mounted) avisar(context, mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comprobante;
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
                SectionCard(
                  title: 'Afecta a ${c.tipoEtiqueta} ${c.numero}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Motivo',
                        style: textos.labelMedium?.copyWith(color: p.text),
                      ),
                      const SizedBox(height: AppSpace.x1 + 2),
                      AppSelectorField<String>(
                        titulo: 'Motivo',
                        icono: LucideIcons.fileText,
                        initialValue: _motivo,
                        opciones: _motivos.entries
                            .map(
                              (m) => AppSelectorOption(
                                value: m.key,
                                label: m.value,
                              ),
                            )
                            .toList(),
                        onChanged: (valor) => setState(() {
                          _motivo = valor!;
                          if (_itemsBloqueados) _restaurarLineas();
                        }),
                      ),
                      const SizedBox(height: AppSpace.x3),
                      CampoTexto(
                        etiqueta: 'Detalle (opcional)',
                        controller: _descripcion,
                        longitudMaxima: 250,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.x3),
                SectionCard(
                  title: 'Ítems',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final linea in _lineas) _filaLinea(linea)],
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.x4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilaDato(
                      'Total estimado',
                      formatearMoneda(_totalEstimado, moneda: c.moneda),
                      destacado: true,
                    ),
                    Text(
                      'El importe final lo calcula el servidor.',
                      style: textos.bodySmall?.copyWith(color: p.textMuted),
                    ),
                    const SizedBox(height: AppSpace.x3),
                    BotonPrimario(
                      texto: _enviando ? 'Emitiendo...' : 'Emitir nota',
                      icono: LucideIcons.send,
                      onPressed: _enviando ? null : _emitir,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaLinea(_LineaNota linea) {
    final editable = !_itemsBloqueados && linea.incluida;
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.x2 + 2),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.x1,
        AppSpace.x1,
        AppSpace.x3,
        AppSpace.x3,
      ),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(AppV2.cardRadius),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            value: linea.incluida,
            title: Text(linea.item.descripcion),
            onChanged: _itemsBloqueados
                ? null
                : (valor) => setState(() => linea.incluida = valor ?? false),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: CampoTexto(
                  etiqueta: 'Cantidad',
                  controller: linea.cantidad,
                  habilitado: editable,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (texto) => _validarCantidad(linea, texto),
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: CampoTexto(
                  etiqueta: 'Precio',
                  controller: linea.precio,
                  habilitado: editable,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (texto) {
                    if (!linea.incluida) return null;
                    final precio = decimalDeEntrada(texto ?? '');
                    return precio == null || precio == Decimal.zero
                        ? 'Inválido'
                        : null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _validarCantidad(_LineaNota linea, String? texto) {
    if (!linea.incluida) return null;
    final cantidad = decimalDeEntrada(texto ?? '');
    if (cantidad == null || cantidad == Decimal.zero) return 'Inválida';
    if (_esCredito && cantidad > linea.item.cantidad) {
      return 'Excede lo emitido';
    }
    return null;
  }
}
