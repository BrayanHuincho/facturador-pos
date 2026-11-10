import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/rutas.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../../../design_system/design_system.dart';
import '../data/ajustes_repository.dart';
import '../domain/ajustes_models.dart';

class BannerModoPrueba extends ConsumerWidget {
  const BannerModoPrueba({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilActualProvider).value;
    if (perfil == null) return const SizedBox.shrink();
    if (perfil.esAdmin) {
      final estado = ref.watch(estadoSunatProvider).value;
      if (estado == null || estado.enProduccion) return const SizedBox.shrink();
      return ModoPruebaBanner(
        message: 'Modo prueba: sin validez',
        actionLabel: 'Pasar a producción',
        onAction: () => context.push(Rutas.ajustesProduccion),
      );
    }
    final ruc = ref.watch(empresaActualProvider).value?.ruc;
    return ruc == rucEmpresaDePrueba
        ? const ModoPruebaBanner()
        : const SizedBox.shrink();
  }
}
