import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/router/rutas.dart';
import '../../../design_system/design_system.dart';
import '../../ajustes/presentation/banner_modo_prueba.dart';
import '../../comprobantes/data/archivos_compartidos.dart';
import '../../comprobantes/domain/comprobante.dart';
import '../../comprobantes/presentation/acciones_documento.dart';
import '../../comprobantes/presentation/documento_comprobante.dart';
import 'cobro_controller.dart';
import 'pos_providers.dart';

class ListoScreen extends ConsumerWidget {
  const ListoScreen({super.key});

  void _nuevaVenta(BuildContext context, WidgetRef ref) {
    ref.read(cobroControllerProvider.notifier).reiniciar();
    context.go(Rutas.pos);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultado = ref.watch(
      cobroControllerProvider.select((e) => e.resultado),
    );
    final p = context.palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) _nuevaVenta(context, ref);
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: resultado == null
            ? Column(
                children: [
                  const AppHeader(title: 'Venta', automaticBack: false),
                  Expanded(
                    child: EmptyState(
                      icon: LucideIcons.receipt,
                      title: 'No hay ninguna venta reciente',
                      actionLabel: 'Ir a vender',
                      onAction: () => _nuevaVenta(context, ref),
                    ),
                  ),
                ],
              )
            : _Contenido(
                resultado: resultado,
                alNuevaVenta: () => _nuevaVenta(context, ref),
              ),
      ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.resultado, required this.alNuevaVenta});

  final ResultadoCobro resultado;
  final VoidCallback alNuevaVenta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final base = resultado.comprobante;
    final id = base?['id'] as String?;
    final enVivo = id == null
        ? null
        : ref.watch(comprobanteEnVivoProvider(id)).value;
    final comprobante = base == null ? null : {...base, ...?enVivo};
    final numero = comprobante == null
        ? null
        : '${comprobante['serie']}-${comprobante['correlativo']}';
    final estado = comprobante == null
        ? null
        : EstadoDocumento.desde(comprobante['estado']);
    final fallo =
        estado == EstadoDocumento.rechazado ||
        estado == EstadoDocumento.error ||
        resultado.rechazo != null;
    final titulo = resultado.rechazo != null
        ? 'Venta rechazada'
        : numero ?? 'Venta en cola';
    return Column(
      children: [
        AppHeader(
          title: titulo,
          subtitle: estado?.etiqueta,
          automaticBack: false,
          actions: [
            if (comprobante != null && numero != null && id != null) ...[
              BotonImprimirCabecera(
                alImprimir: () =>
                    imprimirComprobante(ref, comprobante: comprobante),
              ),
              Builder(
                builder: (contexto) => AppHeaderAction(
                  icon: LucideIcons.share2,
                  tooltip: 'Compartir',
                  onPressed: () => ejecutarConAviso(
                    contexto,
                    () => compartirComprobantePdf(
                      ref,
                      id: id,
                      numero: numero,
                      origen: origenCompartir(contexto),
                    ),
                  ),
                ),
              ),
              BotonWhatsappCabecera(
                celular: resultado.cliente?.telefono,
                alEnviar: (celular) => enviarComprobantePorWhatsapp(
                  ref,
                  id: id,
                  numero: numero,
                  celular: celular,
                ),
              ),
            ],
          ],
        ),
        const BannerModoPrueba(),
        if (resultado.rechazo != null)
          _Aviso(resultado.rechazo!, color: p.danger, fondo: p.dangerSoft)
        else if (fallo && comprobante != null)
          _Aviso(
            'SUNAT marcó este comprobante como ${estado!.etiqueta.toLowerCase()}. Revísalo en Comprobantes.',
            color: p.danger,
            fondo: p.dangerSoft,
          ),
        if (resultado.avisoImpresion != null)
          _Aviso(
            resultado.avisoImpresion!,
            color: p.warning,
            fondo: p.warningSoft,
          ),
        Expanded(
          child: comprobante != null
              ? DocumentoComprobante(
                  comprobanteId: id!,
                  refresco: comprobante['estado'],
                )
              : EmptyState(
                  icon: LucideIcons.cloudUpload,
                  title: resultado.rechazo == null
                      ? 'Guardada para enviar'
                      : 'No se emitió el comprobante',
                  message: resultado.rechazo == null
                      ? 'Se enviará a SUNAT cuando vuelva la conexión.'
                      : 'Corrige el motivo y vuelve a registrar la venta.',
                ),
        ),
        _Pie(vuelto: resultado.vuelto, alNuevaVenta: alNuevaVenta),
      ],
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie({required this.vuelto, required this.alNuevaVenta});

  final Decimal vuelto;
  final VoidCallback alNuevaVenta;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.x3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vuelto > Decimal.zero)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpace.x2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.x3,
                    vertical: AppSpace.x2,
                  ),
                  decoration: BoxDecoration(
                    color: p.successSoft,
                    borderRadius: AppRadii.mdAll,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Vuelto',
                          style: t.titleSmall?.copyWith(
                            color: p.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      MoneyText(
                        vuelto,
                        size: MoneySize.large,
                        color: p.success,
                      ),
                    ],
                  ),
                ),
              AppButton(
                label: 'Nueva venta',
                icon: LucideIcons.plus,
                size: AppButtonSize.large,
                expand: true,
                onPressed: alNuevaVenta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto, {required this.color, required this.fondo});

  final String texto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: fondo,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x4,
        vertical: AppSpace.x2,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, size: AppSizes.iconSm, color: color),
          const SizedBox(width: AppSpace.x2),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    ),
  );
}
