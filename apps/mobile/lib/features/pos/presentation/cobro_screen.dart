import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/router/rutas.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../../../design_system/design_system.dart';
import '../../ajustes/presentation/banner_modo_prueba.dart';
import '../domain/cobro.dart';
import '../domain/dinero.dart';
import 'cobro_controller.dart';
import 'pos_providers.dart';
import 'widgets/cliente_seccion.dart';
import 'widgets/medio_pago_logo.dart';
import 'widgets/qr_grande.dart';

const _gap = SizedBox(height: AppSpace.x3);
final List<Decimal> _billetes = [10, 20, 50, 100].map(Decimal.fromInt).toList();

class CobroScreen extends ConsumerStatefulWidget {
  const CobroScreen({super.key});

  @override
  ConsumerState<CobroScreen> createState() => _CobroScreenState();
}

class _CobroScreenState extends ConsumerState<CobroScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(carritoProvider).vacio) {
        context.go(Rutas.pos);
        return;
      }
      ref.read(cobroControllerProvider.notifier).iniciar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(cobroControllerProvider);
    final p = context.palette;
    final total =
        estado.previsualizacion?.total ??
        ref.read(cobroControllerProvider.notifier).totalVigente;
    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          AppHeader(titleWidget: _TituloCobrar(total: total)),
          const BannerModoPrueba(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, restricciones) {
                if (restricciones.maxWidth >= AppBreakpoints.expanded) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.x6,
                            AppSpace.x5,
                            AppSpace.x3,
                            AppSpace.x6,
                          ),
                          children: const [
                            _SeccionDocumento(),
                            _gap,
                            ClienteSeccion(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.x3,
                            AppSpace.x5,
                            AppSpace.x6,
                            AppSpace.x6,
                          ),
                          children: const [_SeccionPagos()],
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.x4,
                    AppSpace.x4,
                    AppSpace.x4,
                    AppSpace.x6,
                  ),
                  children: const [
                    _SeccionDocumento(),
                    _gap,
                    ClienteSeccion(),
                    _gap,
                    _SeccionPagos(),
                  ],
                );
              },
            ),
          ),
          const _BarraCobrar(),
        ],
      ),
    );
  }
}

class _TituloCobrar extends StatelessWidget {
  const _TituloCobrar({required this.total});

  final Decimal total;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Text(
          'Cobrar',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: p.onHeader,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpace.x3),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpace.x2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: MoneyText(
                  total,
                  size: MoneySize.large,
                  color: p.onHeader,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeccionDocumento extends ConsumerWidget {
  const _SeccionDocumento();

  IconData _icono(TipoDocumentoVenta tipo) =>
      tipo.etiqueta.toLowerCase().contains('factura')
      ? LucideIcons.building2
      : LucideIcons.receiptText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(cobroControllerProvider);
    final controlador = ref.read(cobroControllerProvider.notifier);
    final notaVenta = ref.watch(modulosEmpresaProvider).notaVenta;
    final tipos = [
      for (final tipo in TipoDocumentoVenta.values)
        if (notaVenta || tipo != TipoDocumentoVenta.notaVenta) tipo,
    ];
    return SectionCard(
      title: 'Comprobante',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final (i, tipo) in tipos.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpace.x2),
                Expanded(
                  child: _BotonTipo(
                    icono: _icono(tipo),
                    etiqueta: tipo.etiqueta,
                    seleccionado: estado.tipo == tipo,
                    alTocar: () => controlador.elegirTipo(tipo),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonTipo extends StatelessWidget {
  const _BotonTipo({
    required this.icono,
    required this.etiqueta,
    required this.seleccionado,
    required this.alTocar,
  });

  final IconData icono;
  final String etiqueta;
  final bool seleccionado;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radio = BorderRadius.circular(12);
    return AnimatedContainer(
      duration: AppMotion.fast,
      decoration: BoxDecoration(
        color: seleccionado
            ? Color.alphaBlend(p.brand.withValues(alpha: 0.06), p.surface)
            : p.surface,
        borderRadius: radio,
        border: Border.all(
          color: seleccionado ? p.brand : p.border,
          width: seleccionado ? 2 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radio,
          onTap: alTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icono,
                  size: 18,
                  color: seleccionado ? p.brand : p.textMuted,
                ),
                const SizedBox(width: AppSpace.x1 + 2),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      etiqueta,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: seleccionado ? p.brand : p.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeccionPagos extends ConsumerWidget {
  const _SeccionPagos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(cobroControllerProvider);
    final controlador = ref.read(cobroControllerProvider.notifier);
    final total = estado.previsualizacion?.total ?? controlador.totalVigente;
    final indiceEfectivo = estado.pagos.indexWhere(
      (p) => p.medio == MedioPago.efectivo,
    );
    final p = context.palette;
    final principal = estado.pagos.isEmpty ? null : estado.pagos.first;
    final empresa = ref.watch(empresaActualProvider).value;
    final medios = [
      for (final codigo in empresa?.mediosPago ?? mediosPagoPorDefecto)
        ?MedioPago.desdeCodigo(codigo),
    ];
    final rutaQr = switch (principal?.medio) {
      MedioPago.yape => empresa?.qrYapePath,
      MedioPago.plin => empresa?.qrPlinPath,
      _ => null,
    };
    final urlQr = ref.read(catalogoRepositoryProvider).urlImagen(rutaQr);
    return SectionCard(
      title: 'Pago',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (principal != null)
            _GrillaMedios(
              medios: medios,
              elegido: principal.medio,
              alElegir: (medio) => controlador.actualizarPago(
                0,
                PagoCobro(medio: medio, monto: principal.monto),
              ),
            ),
          const SizedBox(height: AppSpace.x3),
          if (principal != null && urlQr != null)
            BloqueQrCobro(
              medio: principal.medio,
              url: urlQr,
              monto: principal.monto,
            ),
          for (var i = 0; i < estado.pagos.length; i++)
            _FilaPago(
              key: ValueKey(i),
              indice: i,
              pago: estado.pagos[i],
              puedeQuitar: estado.pagos.length > 1,
              onCambio: (pago) => controlador.actualizarPago(i, pago),
              onQuitar: () => controlador.quitarPago(i),
            ),
          if (indiceEfectivo >= 0) ...[
            const SizedBox(height: AppSpace.x1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipBillete(
                    etiqueta: 'Exacto',
                    icono: LucideIcons.checkCheck,
                    alTocar: () => controlador.actualizarPago(
                      indiceEfectivo,
                      PagoCobro(medio: MedioPago.efectivo, monto: total),
                    ),
                  ),
                  for (final billete in _billetes) ...[
                    const SizedBox(width: AppSpace.x2),
                    _ChipBillete(
                      etiqueta: 'S/ $billete',
                      icono: LucideIcons.banknote,
                      alTocar: () => controlador.actualizarPago(
                        indiceEfectivo,
                        PagoCobro(medio: MedioPago.efectivo, monto: billete),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.x2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controlador.agregarPago,
              icon: Icon(
                LucideIcons.plus,
                size: AppSizes.iconMd,
                color: p.brand,
              ),
              label: const Text('Agregar pago'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrillaMedios extends StatelessWidget {
  const _GrillaMedios({
    required this.medios,
    required this.elegido,
    required this.alElegir,
  });

  final List<MedioPago> medios;
  final MedioPago elegido;
  final ValueChanged<MedioPago> alElegir;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpace.x2,
      crossAxisSpacing: AppSpace.x2,
      childAspectRatio: 0.86,
      children: [
        for (final medio in medios)
          _TileMedio(
            medio: medio,
            seleccionado: medio == elegido,
            alTocar: () => alElegir(medio),
          ),
      ],
    );
  }
}

class _TileMedio extends StatelessWidget {
  const _TileMedio({
    required this.medio,
    required this.seleccionado,
    required this.alTocar,
  });

  final MedioPago medio;
  final bool seleccionado;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radio = BorderRadius.circular(12);
    return Semantics(
      selected: seleccionado,
      button: true,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        decoration: BoxDecoration(
          color: seleccionado
              ? Color.alphaBlend(p.brand.withValues(alpha: 0.06), p.surface)
              : p.surface,
          borderRadius: radio,
          border: Border.all(
            color: seleccionado ? p.brand : p.border,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radio,
            onTap: alTocar,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MedioPagoLogo(medio, size: 34),
                  const SizedBox(height: AppSpace.x1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      medio.etiqueta,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: seleccionado ? p.brand : p.text,
                      ),
                    ),
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

class _ChipBillete extends StatelessWidget {
  const _ChipBillete({
    required this.etiqueta,
    required this.icono,
    required this.alTocar,
  });

  final String etiqueta;
  final IconData icono;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.brandSoft,
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        borderRadius: AppRadii.mdAll,
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x3,
            vertical: AppSpace.x2 + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: AppSizes.iconSm, color: p.brand),
              const SizedBox(width: AppSpace.x1 + 2),
              Text(
                etiqueta,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: p.brand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaPago extends StatefulWidget {
  const _FilaPago({
    required this.indice,
    required this.pago,
    required this.puedeQuitar,
    required this.onCambio,
    required this.onQuitar,
    super.key,
  });

  final int indice;
  final PagoCobro pago;
  final bool puedeQuitar;
  final ValueChanged<PagoCobro> onCambio;
  final VoidCallback onQuitar;

  @override
  State<_FilaPago> createState() => _FilaPagoState();
}

class _FilaPagoState extends State<_FilaPago> {
  late final _monto = TextEditingController(text: importe(widget.pago.monto));

  @override
  void didUpdateWidget(_FilaPago anterior) {
    super.didUpdateWidget(anterior);
    final escrito = decimalDeEntrada(_monto.text) ?? cero;
    if (escrito != widget.pago.monto) _monto.text = importe(widget.pago.monto);
  }

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  void _emitir({MedioPago? medio}) => widget.onCambio(
    PagoCobro(
      medio: medio ?? widget.pago.medio,
      monto: decimalDeEntrada(_monto.text) ?? cero,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final efectivo = widget.pago.medio == MedioPago.efectivo;
    final campoMonto = TextField(
      controller: _monto,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: Theme.of(context).textTheme.titleMedium,
      decoration: InputDecoration(
        prefixText: 'S/ ',
        labelText: efectivo ? 'Recibido' : 'Monto',
        isDense: true,
      ),
      onChanged: (_) => _emitir(),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.indice > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.x2),
              child: Row(
                children: [
                  Expanded(
                    child: AppSelectorField<MedioPago>(
                      key: ValueKey(widget.pago.medio),
                      titulo: 'Medio de pago',
                      initialValue: widget.pago.medio,
                      opciones: [
                        for (final medio in MedioPago.values.where(
                          (m) => m != MedioPago.otro,
                        ))
                          AppSelectorOption(
                            value: medio,
                            label: medio.etiqueta,
                            leading: MedioPagoLogo(medio, size: 36),
                          ),
                      ],
                      onChanged: (medio) => _emitir(medio: medio),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              if (widget.indice == 0) ...[
                MedioPagoLogo(widget.pago.medio, size: 44),
                const SizedBox(width: AppSpace.x3),
              ],
              Expanded(child: campoMonto),
              if (widget.puedeQuitar)
                IconButton(
                  tooltip: 'Quitar pago',
                  onPressed: widget.onQuitar,
                  icon: Icon(
                    LucideIcons.x,
                    size: AppSizes.iconMd,
                    color: p.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarraCobrar extends ConsumerStatefulWidget {
  const _BarraCobrar();

  @override
  ConsumerState<_BarraCobrar> createState() => _BarraCobrarState();
}

class _BarraCobrarState extends ConsumerState<_BarraCobrar> {
  bool _abriendo = false;

  Future<void> _revisar() async {
    if (_abriendo) return;
    _abriendo = true;
    await context.push<void>(Rutas.posVistaPrevia);
    _abriendo = false;
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(cobroControllerProvider);
    final controlador = ref.read(cobroControllerProvider.notifier);
    final vista = estado.previsualizacion;
    final total = vista?.total ?? controlador.totalVigente;
    final motivo = vista == null ? null : controlador.bloqueo(total);
    final puedeCobrar =
        vista != null &&
        motivo == null &&
        !estado.cargandoPrevisualizacion &&
        !estado.procesando;
    final resumen = vista == null
        ? null
        : ResumenPagos(estado.pagos, vista.total);
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.x3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vista != null && vista.estimada)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.x2),
                  child: Text(
                    'Sin conexión: importes estimados.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: p.warning),
                  ),
                ),
              if (estado.cargandoPrevisualizacion)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpace.x2),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (motivo != null &&
                  !(resumen != null && resumen.faltante > cero))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.x2),
                  child: Text(
                    motivo,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (resumen != null && resumen.vuelto > cero)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.x2),
                  child: Text(
                    'Vuelto ${soles(resumen.vuelto)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: p.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else if (resumen != null && resumen.faltante > cero)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.x2),
                  child: Text(
                    'Falta ${soles(resumen.faltante)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: p.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (estado.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.x2),
                  child: Text(
                    estado.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (vista == null && !estado.cargandoPrevisualizacion)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.x2),
                  child: AppButton(
                    label: 'Recalcular',
                    icon: LucideIcons.refreshCw,
                    variant: AppButtonVariant.secondary,
                    expand: true,
                    onPressed: controlador.actualizarPrevisualizacion,
                  ),
                ),
              AppButton(
                label: 'Cobrar ${soles(total)}',
                icon: LucideIcons.check,
                size: AppButtonSize.large,
                expand: true,
                onPressed: puedeCobrar ? _revisar : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
