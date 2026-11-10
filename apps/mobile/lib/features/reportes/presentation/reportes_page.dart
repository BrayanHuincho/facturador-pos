import 'package:facturador_pos/core/sesion/sesion_providers.dart';
import 'package:facturador_pos/design_system/design_system.dart';
import 'package:facturador_pos/features/comprobantes/data/archivos_compartidos.dart';
import 'package:facturador_pos/features/comprobantes/domain/importes.dart';
import 'package:facturador_pos/features/comprobantes/presentation/widgets_documento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/reporte_pdf.dart';
import '../domain/reporte.dart';
import 'reporte_pdf_page.dart';
import 'reportes_controller.dart';

final DateFormat _fechaCorta = DateFormat('dd/MM/yyyy');
const _productosVisibles = 8;

class ReportesPage extends ConsumerStatefulWidget {
  const ReportesPage({super.key});

  @override
  ConsumerState<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends ConsumerState<ReportesPage> {
  bool _exportando = false;
  bool _generandoPdf = false;

  Future<void> _exportarCsv(BuildContext contexto) async {
    if (_exportando) return;
    final origen = origenCompartir(contexto);
    setState(() => _exportando = true);
    try {
      final controlador = ref.read(reportesProvider.notifier);
      final estado = ref.read(reportesProvider);
      final contenido = await controlador.exportarCsv();
      await compartirTexto(
        contenido: contenido,
        nombre:
            'ventas_${fechaApi(estado.desde)}_${fechaApi(estado.hasta)}.csv',
        titulo: 'Reporte de ventas',
        origen: origen,
      );
    } catch (error) {
      if (mounted) avisar(context, mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _elegirPeriodo(EstadoReportes estado) async {
    final elegido = await AppSelectorSheet.show<PeriodoReporte>(
      context,
      title: 'Periodo',
      selected: estado.periodo,
      options: [
        for (final periodo in PeriodoReporte.values)
          AppSelectorOption(value: periodo, label: periodo.etiqueta),
      ],
    );
    if (elegido == null || !mounted) return;
    final controlador = ref.read(reportesProvider.notifier);
    if (elegido != PeriodoReporte.rango) {
      await controlador.elegirPeriodo(elegido);
      return;
    }
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: estado.desde, end: estado.hasta),
    );
    if (rango != null) await controlador.elegirRango(rango.start, rango.end);
  }

  Future<void> _generarPdf() async {
    final estado = ref.read(reportesProvider);
    final kpis = estado.kpis;
    if (kpis == null || _generandoPdf) return;
    setState(() => _generandoPdf = true);
    try {
      final empresa = await ref.read(empresaActualProvider.future);
      final bytes = await construirReportePdf(
        DatosReportePdf(
          empresa: empresa?.razonSocial ?? '',
          desde: estado.desde,
          hasta: estado.hasta,
          kpis: kpis,
          porDia: estado.porDia,
          porMedio: estado.porMedio,
          porProducto: estado.porProducto,
        ),
      );
      if (!mounted) return;
      final nombre =
          'reporte_${fechaApi(estado.desde)}_${fechaApi(estado.hasta)}.pdf';
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => ReportePdfPage(bytes: bytes, nombre: nombre),
        ),
      );
    } catch (error) {
      if (mounted) avisar(context, mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(reportesProvider);
    final controlador = ref.read(reportesProvider.notifier);
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Reportes',
            automaticBack: false,
            actions: [
              Builder(
                builder: (contexto) => AppHeaderAction(
                  icon: LucideIcons.fileSpreadsheet,
                  tooltip: 'Compartir CSV',
                  label: 'CSV',
                  onPressed: _exportando ? null : () => _exportarCsv(contexto),
                ),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controlador.cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpace.x4),
                children: [
                  _SelectorPeriodo(
                    estado: estado,
                    alTocar: () => _elegirPeriodo(estado),
                  ),
                  const SizedBox(height: AppSpace.x3),
                  if (estado.error != null)
                    EstadoVacio(
                      mensaje: mensajeDeError(estado.error!),
                      alReintentar: controlador.cargar,
                    ),
                  if (estado.kpis == null && estado.cargando)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (estado.kpis != null)
                    AnimatedOpacity(
                      opacity: estado.cargando ? 0.5 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: _Resumen(estado: estado),
                    ),
                ],
              ),
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
                padding: const EdgeInsets.all(AppSpace.x3),
                child: AppButton(
                  label: 'Generar reporte PDF',
                  icon: LucideIcons.fileText,
                  size: AppButtonSize.large,
                  expand: true,
                  loading: _generandoPdf,
                  onPressed: estado.kpis == null ? null : _generarPdf,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorPeriodo extends StatelessWidget {
  const _SelectorPeriodo({required this.estado, required this.alTocar});

  final EstadoReportes estado;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x3,
        vertical: AppSpace.x2 + 2,
      ),
      leading: IconChip(LucideIcons.calendar, size: 36, color: p.brand),
      title: estado.periodo.etiqueta,
      subtitle:
          '${_fechaCorta.format(estado.desde)} – ${_fechaCorta.format(estado.hasta)}',
      trailing: Icon(
        LucideIcons.chevronDown,
        size: AppSizes.iconMd,
        color: p.textMuted,
      ),
      onTap: alTocar,
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.estado});

  final EstadoReportes estado;

  @override
  Widget build(BuildContext context) {
    final kpis = estado.kpis!;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Ventas netas',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoneyText(
                kpis.ventasNetas,
                size: MoneySize.display,
                color: p.brand,
              ),
              Text(
                '${kpis.documentosVenta} '
                '${kpis.documentosVenta == 1 ? 'documento' : 'documentos'}',
                style: t.bodySmall?.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: AppSpace.x3),
              Divider(height: 1, color: p.border),
              const SizedBox(height: AppSpace.x2),
              _Linea('Ventas brutas', kpis.ventasBrutas),
              _Linea('IGV', kpis.igv),
              _Linea('Notas de crédito', kpis.notasCredito),
              _Linea('Notas de débito', kpis.notasDebito),
              _Linea('Ticket promedio', kpis.ticketPromedio),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.x3),
        _Desglose(
          titulo: 'Por medio de pago',
          filas: estado.porMedio.map(etiquetaFilaMedio).toList(),
        ),
        const SizedBox(height: AppSpace.x3),
        _Desglose(
          titulo: 'Productos más vendidos',
          filas: estado.porProducto.take(_productosVisibles).toList(),
        ),
        const SizedBox(height: AppSpace.x3),
        _Desglose(titulo: 'Por día', filas: estado.porDia),
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.etiqueta, this.valor);

  final String etiqueta;
  final Object valor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: t.bodyMedium?.copyWith(color: p.textMuted),
            ),
          ),
          Text(
            formatearMoneda(decimalDe(valor)),
            style: t.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _Desglose extends StatelessWidget {
  const _Desglose({required this.titulo, required this.filas});

  final String titulo;
  final List<FilaVenta> filas;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return SectionCard(
      title: titulo,
      child: filas.isEmpty
          ? Text(
              'Sin ventas en este periodo.',
              style: t.bodySmall?.copyWith(color: p.textMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final fila in filas)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fila.etiqueta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpace.x3),
                        Text(
                          '${fila.documentos}',
                          style: t.bodySmall?.copyWith(color: p.textMuted),
                        ),
                        const SizedBox(width: AppSpace.x4),
                        Text(
                          formatearMoneda(fila.total),
                          style: t.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: AppTypography.tabular,
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
