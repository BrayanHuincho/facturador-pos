import 'package:decimal/decimal.dart';
import 'package:facturador_pos/features/comprobantes/domain/importes.dart';
import 'package:facturador_pos/features/comprobantes/presentation/widgets_documento.dart';
import 'package:facturador_pos/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/caja_repository.dart';
import '../domain/caja.dart';

final DateFormat _formatoFechaHora = DateFormat('dd/MM/yyyy HH:mm');

String _fechaHora(DateTime? momento) =>
    momento == null ? '-' : _formatoFechaHora.format(momento.toLocal());

String _soles(Decimal valor) => formatearMoneda(valor);

class CajaPage extends ConsumerStatefulWidget {
  const CajaPage({super.key});

  @override
  ConsumerState<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends ConsumerState<CajaPage> {
  bool _ocupado = false;

  CajaRepository get _repositorio => ref.read(cajaRepositoryProvider);

  void _refrescar() {
    ref.invalidate(turnoActualProvider);
    ref.invalidate(movimientosTurnoProvider);
    ref.invalidate(turnosCerradosProvider);
  }

  Future<T?> _ejecutar<T>(Future<T> Function() accion) async {
    if (_ocupado) return null;
    setState(() => _ocupado = true);
    try {
      final resultado = await accion();
      if (mounted) _refrescar();
      return resultado;
    } catch (error) {
      if (mounted) avisar(context, mensajeDeError(error));
      return null;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrir() async {
    final monto = await showDialog<Decimal>(
      context: context,
      builder: (_) => const _DialogoApertura(),
    );
    if (monto == null) return;
    await _ejecutar(() => _repositorio.abrir(monto));
  }

  Future<void> _registrarMovimiento(String tipo) async {
    final datos = await showDialog<(Decimal, String)>(
      context: context,
      builder: (_) => _DialogoMovimiento(tipo: tipo),
    );
    if (datos == null) return;
    await _ejecutar(
      () => _repositorio.registrarMovimiento(
        tipo: tipo,
        monto: datos.$1,
        concepto: datos.$2,
      ),
    );
  }

  Future<void> _cerrar(ResumenTurno resumen) async {
    final datos = await showDialog<(Decimal, String)>(
      context: context,
      builder: (_) => _DialogoCierre(esperado: resumen.montoEsperado),
    );
    if (datos == null) return;
    final cerrado = await _ejecutar(
      () => _repositorio.cerrar(datos.$1, datos.$2),
    );
    if (cerrado == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (contexto) => AppDialog(
        title: const Text('Turno cerrado'),
        content: _DetalleCierre(turno: cerrado.turno),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actual = ref.watch(turnoActualProvider);
    return Scaffold(
      backgroundColor: context.palette.background,
      body: Column(
        children: [
          const AppHeader(title: 'Caja', automaticBack: false),
          if (_ocupado) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: actual.when(
              skipLoadingOnReload: true,
              loading: () => SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpace.x4),
                child: Skeleton.list(rows: 5),
              ),
              error: (error, _) => EstadoVacio(
                mensaje: mensajeDeError(error),
                alReintentar: _refrescar,
              ),
              data: (datos) => RefreshIndicator(
                onRefresh: () async => _refrescar(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (datos == null)
                      _SinTurno(alAbrir: _ocupado ? null : _abrir)
                    else ...[
                      _TarjetaResumen(datos: datos),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Ingreso',
                              icon: LucideIcons.arrowDownLeft,
                              variant: AppButtonVariant.secondary,
                              expand: true,
                              onPressed: _ocupado
                                  ? null
                                  : () => _registrarMovimiento('ingreso'),
                            ),
                          ),
                          const SizedBox(width: AppSpace.x3),
                          Expanded(
                            child: AppButton(
                              label: 'Egreso',
                              icon: LucideIcons.arrowUpRight,
                              variant: AppButtonVariant.secondary,
                              expand: true,
                              onPressed: _ocupado
                                  ? null
                                  : () => _registrarMovimiento('egreso'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.x3),
                      AppButton(
                        label: 'Cerrar turno',
                        icon: LucideIcons.lock,
                        expand: true,
                        size: AppButtonSize.large,
                        onPressed: _ocupado
                            ? null
                            : () => _cerrar(datos.resumen),
                      ),
                      const SizedBox(height: AppSpace.x3),
                      _ListaMovimientos(turnoId: datos.turno.id),
                    ],
                    const SizedBox(height: 12),
                    const _TurnosCerrados(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SinTurno extends StatelessWidget {
  const _SinTurno({required this.alAbrir});

  final VoidCallback? alAbrir;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x3),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.x5),
        child: Column(
          children: [
            IconChip(LucideIcons.wallet, size: 56),
            const SizedBox(height: AppSpace.x3),
            Text('Sin turno abierto', style: t.titleMedium),
            const SizedBox(height: AppSpace.x1),
            Text(
              'Abre un turno para registrar ventas en efectivo.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: AppSpace.x4),
            AppButton(
              label: 'Abrir turno',
              icon: LucideIcons.lockOpen,
              size: AppButtonSize.large,
              expand: true,
              onPressed: alAbrir,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilasResumen extends StatelessWidget {
  const _FilasResumen({required this.resumen});

  final ResumenTurno resumen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilaDato('Apertura', _soles(resumen.montoApertura)),
        FilaDato('Ventas en efectivo', _soles(resumen.ventasEfectivo)),
        FilaDato('Vuelto entregado', _soles(resumen.vuelto)),
        FilaDato('Ingresos', _soles(resumen.ingresos)),
        FilaDato('Egresos', _soles(resumen.egresos)),
        FilaDato(
          'Efectivo esperado',
          _soles(resumen.montoEsperado),
          destacado: true,
        ),
        const Divider(),
        FilaDato('Total ventas', _soles(resumen.totalVentas)),
        for (final medio in resumen.porMedio)
          FilaDato(medio.medio, _soles(medio.total)),
      ],
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({required this.datos});

  final TurnoConResumen datos;

  @override
  Widget build(BuildContext context) {
    final r = datos.resumen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  icon: LucideIcons.banknote,
                  label: 'Efectivo esperado',
                  amount: r.montoEsperado,
                  color: context.palette.success,
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: StatCard(
                  icon: LucideIcons.trendingUp,
                  label: 'Total ventas',
                  amount: r.totalVentas,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.x3),
        SeccionDocumento(
          titulo: 'Turno abierto desde ${_fechaHora(datos.turno.abiertoEn)}',
          children: [_FilasResumen(resumen: r)],
        ),
      ],
    );
  }
}

class _DetalleCierre extends StatelessWidget {
  const _DetalleCierre({required this.turno});

  final Turno turno;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (turno.montoEsperado != null)
          FilaDato('Esperado', _soles(turno.montoEsperado!)),
        if (turno.montoContado != null)
          FilaDato('Contado', _soles(turno.montoContado!)),
        if (turno.diferencia != null)
          FilaDato('Diferencia', _soles(turno.diferencia!), destacado: true),
        if (turno.observacion != null && turno.observacion!.isNotEmpty)
          FilaDato('Observación', turno.observacion!),
      ],
    );
  }
}

class _ListaMovimientos extends ConsumerWidget {
  const _ListaMovimientos({required this.turnoId});

  final String turnoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientos = ref.watch(movimientosTurnoProvider(turnoId));
    return SeccionDocumento(
      titulo: 'Movimientos del turno',
      children: [
        movimientos.when(
          skipLoadingOnReload: true,
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(mensajeDeError(error)),
          data: (lista) => lista.isEmpty
              ? const Text('Sin movimientos.')
              : Column(
                  children: [
                    for (final movimiento in lista)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.x2),
                        child: Row(
                          children: [
                            IconChip(
                              movimiento.esIngreso
                                  ? LucideIcons.arrowDownLeft
                                  : LucideIcons.arrowUpRight,
                              size: 36,
                              color: movimiento.esIngreso
                                  ? context.palette.success
                                  : context.palette.danger,
                            ),
                            const SizedBox(width: AppSpace.x3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movimiento.concepto,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  Text(
                                    _fechaHora(movimiento.creadoEn),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${movimiento.esIngreso ? '+' : '-'} '
                              '${_soles(movimiento.monto)}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TurnosCerrados extends ConsumerWidget {
  const _TurnosCerrados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turnos = ref.watch(turnosCerradosProvider);
    return SeccionDocumento(
      titulo: 'Turnos anteriores',
      children: [
        turnos.when(
          skipLoadingOnReload: true,
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(mensajeDeError(error)),
          data: (lista) => lista.isEmpty
              ? const Text('Aún no hay turnos cerrados.')
              : Column(
                  children: [
                    for (final turno in lista)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.x2),
                        child: ListCard(
                          leading: const IconChip(LucideIcons.lock, size: 38),
                          title: _fechaHora(turno.cerradoEn),
                          subtitle:
                              'Diferencia ${_soles(turno.diferencia ?? Decimal.zero)}',
                          trailing: Icon(
                            LucideIcons.chevronRight,
                            size: AppSizes.iconMd,
                            color: context.palette.textMuted,
                          ),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            useRootNavigator: true,
                            isScrollControlled: true,
                            builder: (_) => _HojaResumen(turnoId: turno.id),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _HojaResumen extends ConsumerWidget {
  const _HojaResumen({required this.turnoId});

  final String turnoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenTurnoProvider(turnoId));
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: resumen.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(mensajeDeError(error)),
          data: (datos) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Turno del ${_fechaHora(datos.turno.abiertoEn)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _FilasResumen(resumen: datos.resumen),
              const Divider(),
              _DetalleCierre(turno: datos.turno),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogoApertura extends StatefulWidget {
  const _DialogoApertura();

  @override
  State<_DialogoApertura> createState() => _DialogoAperturaState();
}

class _DialogoAperturaState extends State<_DialogoApertura> {
  final _formulario = GlobalKey<FormState>();
  final _monto = TextEditingController();

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: const Text('Abrir turno'),
      content: Form(
        key: _formulario,
        child: TextFormField(
          controller: _monto,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monto de apertura'),
          validator: (texto) => validarMonto(texto, permitirCero: true),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formulario.currentState!.validate()) {
              Navigator.pop(context, decimalDeEntrada(_monto.text));
            }
          },
          child: const Text('Abrir'),
        ),
      ],
    );
  }
}

class _DialogoMovimiento extends StatefulWidget {
  const _DialogoMovimiento({required this.tipo});

  final String tipo;

  @override
  State<_DialogoMovimiento> createState() => _DialogoMovimientoState();
}

class _DialogoMovimientoState extends State<_DialogoMovimiento> {
  final _formulario = GlobalKey<FormState>();
  final _monto = TextEditingController();
  final _concepto = TextEditingController();

  @override
  void dispose() {
    _monto.dispose();
    _concepto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(widget.tipo == 'ingreso' ? 'Nuevo ingreso' : 'Nuevo egreso'),
      content: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _monto,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Monto'),
              validator: validarMonto,
            ),
            TextFormField(
              controller: _concepto,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Concepto'),
              validator: (texto) =>
                  (texto ?? '').trim().isEmpty ? 'Indica el concepto' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formulario.currentState!.validate()) {
              Navigator.pop(context, (
                decimalDeEntrada(_monto.text)!,
                _concepto.text.trim(),
              ));
            }
          },
          child: const Text('Registrar'),
        ),
      ],
    );
  }
}

class _DialogoCierre extends StatefulWidget {
  const _DialogoCierre({required this.esperado});

  final Decimal esperado;

  @override
  State<_DialogoCierre> createState() => _DialogoCierreState();
}

class _DialogoCierreState extends State<_DialogoCierre> {
  final _formulario = GlobalKey<FormState>();
  final _contado = TextEditingController();
  final _observacion = TextEditingController();

  @override
  void dispose() {
    _contado.dispose();
    _observacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contado = decimalDeEntrada(_contado.text);
    return AppDialog(
      title: const Text('Cerrar turno'),
      content: Form(
        key: _formulario,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilaDato('Efectivo esperado', _soles(widget.esperado)),
              TextFormField(
                controller: _contado,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Efectivo contado',
                ),
                validator: (texto) => validarMonto(texto, permitirCero: true),
              ),
              const SizedBox(height: 8),
              FilaDato(
                'Diferencia',
                contado == null ? '-' : _soles(contado - widget.esperado),
                destacado: true,
              ),
              TextFormField(
                controller: _observacion,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Observación'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formulario.currentState!.validate()) {
              Navigator.pop(context, (
                decimalDeEntrada(_contado.text)!,
                _observacion.text.trim(),
              ));
            }
          },
          child: const Text('Cerrar turno'),
        ),
      ],
    );
  }
}
