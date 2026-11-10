import 'dart:async';

import 'package:facturador_pos/core/router/rutas.dart';
import 'package:facturador_pos/core/sesion/sesion_providers.dart';
import 'package:facturador_pos/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ajustes/presentation/banner_modo_prueba.dart';
import '../domain/comprobante.dart';
import '../domain/importes.dart';
import 'comprobantes_controller.dart';
import 'widgets_documento.dart';

final DateFormat _formatoFecha = DateFormat('yyyy-MM-dd');

class ComprobantesPage extends ConsumerStatefulWidget {
  const ComprobantesPage({super.key});

  @override
  ConsumerState<ComprobantesPage> createState() => _ComprobantesPageState();
}

class _ComprobantesPageState extends ConsumerState<ComprobantesPage> {
  final _desplazamiento = ScrollController();
  final _busqueda = TextEditingController();
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    _desplazamiento.addListener(_alDesplazar);
  }

  @override
  void dispose() {
    _espera?.cancel();
    _desplazamiento.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  void _alDesplazar() {
    if (_desplazamiento.position.extentAfter < 400) {
      ref.read(listadoComprobantesProvider.notifier).cargarMas();
    }
  }

  void _alBuscar(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), () {
      final actuales = ref.read(listadoComprobantesProvider).filtros;
      ref
          .read(listadoComprobantesProvider.notifier)
          .aplicarFiltros(
            FiltrosComprobantes(
              tipo: actuales.tipo,
              estado: actuales.estado,
              desde: actuales.desde,
              hasta: actuales.hasta,
              busqueda: texto,
            ),
          );
    });
  }

  Future<void> _filtrarTipo(FiltrosComprobantes actuales, String? tipo) => ref
      .read(listadoComprobantesProvider.notifier)
      .aplicarFiltros(
        FiltrosComprobantes(
          tipo: tipo,
          estado: actuales.estado,
          desde: actuales.desde,
          hasta: actuales.hasta,
          busqueda: actuales.busqueda,
        ),
      );

  Future<void> _abrirFiltros(FiltrosComprobantes actuales) async {
    final filtros = await showModalBottomSheet<FiltrosComprobantes>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _HojaFiltros(actuales: actuales),
    );
    if (filtros != null) {
      await ref
          .read(listadoComprobantesProvider.notifier)
          .aplicarFiltros(filtros);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listado = ref.watch(listadoComprobantesProvider);
    final p = context.palette;
    final notaVenta = ref.watch(modulosEmpresaProvider).notaVenta;
    final pestanas = <(String?, String)>[
      (null, 'Todos'),
      ('03', 'Boletas'),
      ('01', 'Facturas'),
      if (notaVenta) ('NV', 'Notas'),
    ];
    final indicePestana = pestanas.indexWhere(
      (e) => e.$1 == listado.filtros.tipo,
    );
    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Comprobantes',
            automaticBack: false,
            actions: [
              if (ref.watch(rolActualProvider) != RolUsuario.cajero)
                AppHeaderAction(
                  icon: LucideIcons.fileStack,
                  tooltip: 'Resúmenes y bajas',
                  onPressed: () =>
                      context.push('${Rutas.comprobantes}/resumenes'),
                ),
              AppHeaderAction(
                icon: listado.filtros.activos
                    ? LucideIcons.funnel
                    : LucideIcons.listFilter,
                tooltip: 'Filtros',
                label: 'Filtros',
                onPressed: () => _abrirFiltros(listado.filtros),
              ),
            ],
            bottom: AppSearchField.onBrand(
              controller: _busqueda,
              hint: 'Número, cliente o documento',
              onChanged: _alBuscar,
            ),
          ),
          ColoredBox(
            color: p.surface,
            child: AppTabs(
              tabs: pestanas.map((e) => e.$2).toList(),
              index: indicePestana < 0 ? 0 : indicePestana,
              onChanged: (i) => _filtrarTipo(listado.filtros, pestanas[i].$1),
            ),
          ),
          const BannerModoPrueba(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(listadoComprobantesProvider.notifier).recargar(),
              child: _contenido(listado),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido(ListadoComprobantes listado) {
    if (listado.items.isEmpty) {
      if (listado.cargando) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpace.x4),
          child: Skeleton.list(rows: 7),
        );
      }
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          EstadoVacio(
            mensaje: listado.error != null
                ? mensajeDeError(listado.error!)
                : 'No hay comprobantes para estos filtros.',
            alReintentar: listado.error != null
                ? () =>
                      ref.read(listadoComprobantesProvider.notifier).recargar()
                : null,
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _desplazamiento,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.x4),
      itemCount: listado.items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.x2),
      itemBuilder: (context, indice) {
        if (indice == listado.items.length) {
          return _PieListado(listado: listado);
        }
        final comprobante = listado.items[indice];
        final p = context.palette;
        final esFactura = comprobante.tipoEtiqueta.toLowerCase().contains(
          'factura',
        );
        return ListCard(
          onTap: () => context.push(Rutas.comprobante(comprobante.id)),
          titleMaxLines: 1,
          leading: IconChip(
            esFactura ? LucideIcons.building2 : LucideIcons.receiptText,
            color: esFactura ? const Color(0xFF7C3AED) : p.brand,
          ),
          title: comprobante.numero,
          subtitle:
              '${comprobante.tipoEtiqueta} · ${comprobante.clienteNombre} · ${comprobante.fechaEmision}',
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatearMoneda(comprobante.total, moneda: comprobante.moneda),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFeatures: AppTypography.tabular,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.x1),
              EstadoChip(codigo: comprobante.estado.codigo),
            ],
          ),
        );
      },
    );
  }
}

class _PieListado extends ConsumerWidget {
  const _PieListado({required this.listado});

  final ListadoComprobantes listado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (listado.cargando) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (listado.error != null) {
      return EstadoVacio(
        mensaje: mensajeDeError(listado.error!),
        alReintentar: () =>
            ref.read(listadoComprobantesProvider.notifier).cargarMas(),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _HojaFiltros extends StatefulWidget {
  const _HojaFiltros({required this.actuales});

  final FiltrosComprobantes actuales;

  @override
  State<_HojaFiltros> createState() => _HojaFiltrosState();
}

class _HojaFiltrosState extends State<_HojaFiltros> {
  late String? _tipo = widget.actuales.tipo;
  late EstadoDocumento? _estado = widget.actuales.estado;
  late String? _desde = widget.actuales.desde;
  late String? _hasta = widget.actuales.hasta;

  Future<void> _elegirRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (rango == null) return;
    setState(() {
      _desde = _formatoFecha.format(rango.start);
      _hasta = _formatoFecha.format(rango.end);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSelectorField<String?>(
                titulo: 'Tipo',
                etiqueta: 'Tipo',
                icono: LucideIcons.receiptText,
                initialValue: _tipo,
                opciones: [
                  const AppSelectorOption(value: null, label: 'Todos'),
                  ...tiposComprobante.entries.map(
                    (t) => AppSelectorOption(value: t.key, label: t.value),
                  ),
                ],
                onChanged: (valor) => setState(() => _tipo = valor),
              ),
              const SizedBox(height: 12),
              AppSelectorField<EstadoDocumento?>(
                titulo: 'Estado',
                etiqueta: 'Estado',
                icono: LucideIcons.circleCheck,
                initialValue: _estado,
                opciones: [
                  const AppSelectorOption(value: null, label: 'Todos'),
                  ...EstadoDocumento.filtrables.map(
                    (e) => AppSelectorOption(value: e, label: e.etiqueta),
                  ),
                ],
                onChanged: (valor) => setState(() => _estado = valor),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: _desde == null ? 'Cualquier fecha' : '$_desde a $_hasta',
                icon: LucideIcons.calendarRange,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: _elegirRango,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        FiltrosComprobantes(busqueda: widget.actuales.busqueda),
                      ),
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        FiltrosComprobantes(
                          tipo: _tipo,
                          estado: _estado,
                          desde: _desde,
                          hasta: _hasta,
                          busqueda: widget.actuales.busqueda,
                        ),
                      ),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
