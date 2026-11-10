import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/router/rutas.dart';
import '../../../core/widgets/visor_pdf.dart';
import '../../../design_system/design_system.dart';
import '../../ajustes/presentation/banner_modo_prueba.dart';
import '../../impresion/domain/impresora.dart';
import '../../impresion/presentation/impresion_providers.dart';
import '../domain/cola_checkout.dart';
import 'cobro_controller.dart';
import 'pos_providers.dart';

final vistaPreviaPdfProvider = FutureProvider.autoDispose<Uint8List>((
  ref,
) async {
  final solicitud = ref.read(cobroControllerProvider.notifier).solicitudActual;
  final config = await ref.read(configImpresoraProvider.future);
  final formato = config.papel == PapelImpresora.mm58 ? 'ticket58' : 'ticket80';
  return ref
      .read(posApiProvider)
      .vistaPrevia(solicitud.cuerpo(), formato: formato);
}, retry: (_, _) => null);

class VistaPreviaScreen extends ConsumerWidget {
  const VistaPreviaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(cobroControllerProvider.select((e) => e.resultado), (_, nuevo) {
      if (nuevo != null) context.go(Rutas.posCobroListo);
    });
    final estado = ref.watch(cobroControllerProvider);
    final controlador = ref.read(cobroControllerProvider.notifier);
    final documento = ref.watch(vistaPreviaPdfProvider);
    final p = context.palette;
    final bloqueado = documento.error is FalloDefinitivo;
    return PopScope(
      canPop: !estado.procesando,
      child: Scaffold(
        backgroundColor: p.background,
        body: Column(
          children: [
            AppHeader(
              title: 'Vista previa',
              actions: [
                _BotonEmitir(
                  enviando: estado.procesando,
                  alEmitir: bloqueado ? null : controlador.cobrar,
                ),
              ],
            ),
            const BannerModoPrueba(),
            if (estado.error != null) _Franja(texto: estado.error!),
            Expanded(
              child: switch (documento) {
                AsyncData(:final value) => KeyedSubtree(
                  key: const ValueKey('vista-previa'),
                  child: VisorPdf(bytes: value),
                ),
                AsyncError(:final error) when error is FalloDefinitivo =>
                  EmptyState(
                    icon: LucideIcons.circleAlert,
                    title: 'No se puede emitir',
                    message: error.mensaje,
                    actionLabel: 'Reintentar',
                    onAction: () => ref.invalidate(vistaPreviaPdfProvider),
                  ),
                AsyncError() => EmptyState(
                  icon: LucideIcons.cloudOff,
                  title: 'No se pudo mostrar la vista previa',
                  message: 'Puedes emitir igual: la venta se enviará al volver la conexión.',
                  actionLabel: 'Reintentar',
                  onAction: () => ref.invalidate(vistaPreviaPdfProvider),
                ),
                _ => const CargandoDocumento(texto: 'Preparando vista previa…'),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonEmitir extends StatelessWidget {
  const _BotonEmitir({required this.enviando, required this.alEmitir});

  final bool enviando;
  final VoidCallback? alEmitir;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.x1),
      child: TextButton.icon(
        onPressed: enviando ? null : alEmitir,
        style: TextButton.styleFrom(
          foregroundColor: p.header,
          backgroundColor: p.onHeader,
          disabledForegroundColor: p.header.withValues(alpha: 0.55),
          disabledBackgroundColor: p.onHeader.withValues(alpha: 0.6),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x3),
          minimumSize: const Size(0, 44),
        ),
        icon: enviando
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(LucideIcons.send, size: 18),
        label: Text(
          enviando ? 'Emitiendo…' : 'Emitir',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _Franja extends StatelessWidget {
  const _Franja({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ColoredBox(
      color: p.dangerSoft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x4,
          vertical: AppSpace.x2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.circleAlert,
              size: AppSizes.iconSm,
              color: p.danger,
            ),
            const SizedBox(width: AppSpace.x2),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: p.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
