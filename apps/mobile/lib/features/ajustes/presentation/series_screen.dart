import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/widgets.dart';
import '../data/ajustes_repository.dart';
import '../domain/ajustes_models.dart';

class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key});

  void _recargar(WidgetRef ref) {
    ref.invalidate(seriesProvider);
    ref.invalidate(establecimientosProvider);
  }

  Future<void> _abrirFormulario(
    BuildContext context,
    List<Establecimiento> establecimientos, {
    SerieComprobante? serie,
  }) => showDialog<void>(
    context: context,
    builder: (_) =>
        _DialogoSerie(establecimientos: establecimientos, serie: serie),
  );

  Future<void> _cambiarActiva(
    BuildContext context,
    WidgetRef ref,
    SerieComprobante serie,
    bool activa,
  ) async {
    try {
      await ref.read(ajustesRepositoryProvider).actualizarSerie(serie.id, {
        'activa': activa,
      });
      ref.invalidate(seriesProvider);
    } catch (error) {
      if (context.mounted) {
        mostrarMensaje(context, mensajeDeError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(seriesProvider);
    final establecimientos = ref.watch(establecimientosProvider);
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Series',
            actions: [
              if (establecimientos.hasValue)
                AppHeaderAction(
                  icon: LucideIcons.plus,
                  tooltip: 'Nueva serie',
                  label: 'Crear',
                  onPressed: () =>
                      _abrirFormulario(context, establecimientos.requireValue),
                ),
            ],
          ),
          Expanded(
            child: ContenidoAsync<List<Establecimiento>>(
              valor: establecimientos,
              onReintentar: () => _recargar(ref),
              builder: (locales) => ContenidoAsync<List<SerieComprobante>>(
                valor: series,
                onReintentar: () => _recargar(ref),
                builder: (filas) {
                  if (filas.isEmpty) {
                    return const EstadoVacio(
                      titulo: 'Sin series',
                      mensaje: 'Crea una serie para poder emitir comprobantes.',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.x4,
                      AppSpace.x2,
                      AppSpace.x4,
                      AppSpace.x6,
                    ),
                    children: [
                      for (final local in locales) ...[
                        if (filas.any((f) => f.establecimientoId == local.id))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpace.x1,
                              AppSpace.x4,
                              AppSpace.x1,
                              AppSpace.x2,
                            ),
                            child: Text(
                              '${local.codigo} · ${local.nombre}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: context.palette.textMuted),
                            ),
                          ),
                        for (final serie in filas.where(
                          (f) => f.establecimientoId == local.id,
                        ))
                          ListCard(
                            margin: const EdgeInsets.only(
                              bottom: AppSpace.x2 + 2,
                            ),
                            dimmed: !serie.activa,
                            leading: const IconChip(LucideIcons.hash),
                            title: serie.serie,
                            subtitle:
                                '${tiposSerie[serie.tipo] ?? serie.tipo} · Último: ${serie.ultimo}',
                            onTap: () => _abrirFormulario(
                              context,
                              locales,
                              serie: serie,
                            ),
                            trailing: Switch(
                              value: serie.activa,
                              onChanged: (activa) =>
                                  _cambiarActiva(context, ref, serie, activa),
                            ),
                          ),
                      ],
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

class _DialogoSerie extends ConsumerStatefulWidget {
  const _DialogoSerie({required this.establecimientos, this.serie});

  final List<Establecimiento> establecimientos;
  final SerieComprobante? serie;

  @override
  ConsumerState<_DialogoSerie> createState() => _DialogoSerieState();
}

class _DialogoSerieState extends ConsumerState<_DialogoSerie> {
  final _formulario = GlobalKey<FormState>();
  late final _codigo = TextEditingController(text: widget.serie?.serie);
  late final _ultimo = TextEditingController(
    text: (widget.serie?.ultimo ?? 0).toString(),
  );
  late String _tipo = widget.serie?.tipo ?? '01';
  late String? _establecimientoId = _establecimientoInicial();
  bool _guardando = false;

  String? _establecimientoInicial() {
    final actual = widget.serie?.establecimientoId;
    if (widget.establecimientos.any((e) => e.id == actual)) return actual;
    return widget.establecimientos.firstOrNull?.id;
  }

  @override
  void dispose() {
    _codigo.dispose();
    _ultimo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final establecimientoId = _establecimientoId;
    if (!_formulario.currentState!.validate() || establecimientoId == null) {
      return;
    }
    setState(() => _guardando = true);
    final repositorio = ref.read(ajustesRepositoryProvider);
    final codigo = _codigo.text.trim().toUpperCase();
    final ultimo = int.parse(_ultimo.text);
    final serie = widget.serie;
    try {
      if (serie == null) {
        await repositorio.crearSerie(
          establecimientoId: establecimientoId,
          tipo: _tipo,
          serie: codigo,
          ultimo: ultimo,
        );
      } else {
        await repositorio.actualizarSerie(serie.id, {
          'establecimiento_id': establecimientoId,
          'tipo': _tipo,
          'serie': codigo,
          'ultimo': ultimo,
        });
      }
      ref.invalidate(seriesProvider);
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
    title: Text(widget.serie == null ? 'Nueva serie' : 'Editar serie'),
    content: Form(
      key: _formulario,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Etiquetado(
              'Establecimiento',
              AppSelectorField<String>(
                titulo: 'Establecimiento',
                icono: LucideIcons.store,
                initialValue: _establecimientoId,
                opciones: [
                  for (final local in widget.establecimientos)
                    AppSelectorOption(
                      value: local.id,
                      label: '${local.codigo} · ${local.nombre}',
                    ),
                ],
                validator: (valor) =>
                    valor == null ? 'Elige un establecimiento' : null,
                onChanged: (valor) =>
                    setState(() => _establecimientoId = valor),
              ),
            ),
            const SizedBox(height: AppSpace.x3),
            _Etiquetado(
              'Tipo',
              AppSelectorField<String>(
                titulo: 'Tipo de comprobante',
                icono: LucideIcons.receiptText,
                initialValue: _tipo,
                opciones: [
                  for (final tipo in tiposSerie.entries)
                    AppSelectorOption(value: tipo.key, label: tipo.value),
                ],
                onChanged: (valor) {
                  if (valor != null) setState(() => _tipo = valor);
                },
              ),
            ),
            const SizedBox(height: AppSpace.x3),
            CampoTexto(
              etiqueta: 'Serie',
              controller: _codigo,
              longitudMaxima: 4,
              capitalizacion: TextCapitalization.characters,
              validator: (valor) => valor?.trim().length == 4
                  ? null
                  : 'La serie tiene 4 caracteres',
            ),
            const SizedBox(height: AppSpace.x3),
            CampoTexto(
              etiqueta: 'Último correlativo',
              controller: _ultimo,
              teclado: TextInputType.number,
              longitudMaxima: 9,
              formateadores: [FilteringTextInputFormatter.digitsOnly],
              ayuda: 'No se puede cambiar si la serie ya tiene documentos.',
              validator: (valor) => int.tryParse(valor ?? '') == null
                  ? 'Escribe un número'
                  : null,
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
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _Etiquetado extends StatelessWidget {
  const _Etiquetado(this.etiqueta, this.hijo);

  final String etiqueta;
  final Widget hijo;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        etiqueta,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: context.palette.text),
      ),
      const SizedBox(height: AppSpace.x1 + 2),
      hijo,
    ],
  );
}
