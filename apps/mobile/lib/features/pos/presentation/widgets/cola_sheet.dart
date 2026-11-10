import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/cola_checkout.dart';
import '../pos_providers.dart';

void mostrarColaSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const _ColaSheet(),
  );
}

class _ColaSheet extends ConsumerWidget {
  const _ColaSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entradas = ref.watch(entradasColaProvider).value ?? const [];
    final cola = ref.watch(colaCheckoutProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ventas en cola',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (entradas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No hay ventas pendientes.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final entrada in entradas)
            ListCard(
              margin: const EdgeInsets.only(bottom: AppSpace.x2),
              leading: IconChip(
                entrada.estado == EstadoEntradaCola.rechazada
                    ? LucideIcons.circleAlert
                    : LucideIcons.clock,
                color: entrada.estado == EstadoEntradaCola.rechazada
                    ? context.palette.danger
                    : context.palette.brand,
              ),
              title: 'Venta ${_hora(entrada.creadoEn)}',
              subtitle: entrada.ultimoError ?? 'Esperando conexión',
              trailing: entrada.estado == EstadoEntradaCola.rechazada
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Reintentar',
                          onPressed: () => cola?.reintentar(entrada.clave),
                          icon: const Icon(LucideIcons.refreshCw),
                        ),
                        IconButton(
                          tooltip: 'Descartar',
                          onPressed: () =>
                              _confirmarDescarte(context, cola, entrada),
                          icon: const Icon(LucideIcons.trash2),
                        ),
                      ],
                    )
                  : null,
            ),
          if (entradas.any((e) => e.estado == EstadoEntradaCola.pendiente))
            FilledButton(
              onPressed: () => cola?.vaciar(),
              child: const Text('Enviar ahora'),
            ),
        ],
      ),
    );
  }

  String _hora(DateTime fecha) {
    final h = fecha.hour.toString().padLeft(2, '0');
    final m = fecha.minute.toString().padLeft(2, '0');
    return '${fecha.day}/${fecha.month} $h:$m';
  }

  Future<void> _confirmarDescarte(
    BuildContext context,
    ColaCheckout? cola,
    EntradaCola entrada,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AppDialog(
        title: const Text('Descartar venta'),
        content: const Text('La venta no se registrará. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmar == true) await cola?.descartar(entrada.clave);
  }
}
