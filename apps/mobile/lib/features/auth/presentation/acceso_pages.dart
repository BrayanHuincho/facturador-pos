import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/sesion/sesion_providers.dart';
import '../../../core/widgets/widgets.dart';

class CargandoPage extends ConsumerWidget {
  const CargandoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hayError = ref.watch(estadoAccesoProvider) == EstadoAcceso.error;
    return Scaffold(
      body: hayError
          ? EstadoError(
              error: 'Revisa tu conexión e inténtalo de nuevo.',
              titulo: 'No se pudo abrir tu cuenta',
              onReintentar: ref.read(controladorSesionProvider).reintentarCarga,
            )
          : const EstadoCargando(),
    );
  }
}

class SinAccesoPage extends ConsumerWidget {
  const SinAccesoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresaPendiente =
        ref.watch(estadoAccesoProvider) == EstadoAcceso.empresaPendiente;
    return Scaffold(
      body: EstadoVacio(
        icono: LucideIcons.lock,
        titulo: empresaPendiente
            ? 'La empresa aún no está configurada'
            : 'Tu cuenta no tiene acceso',
        mensaje: empresaPendiente
            ? 'Pide al administrador que complete la configuración inicial.'
            : 'Pide al administrador que active tu usuario.',
        textoAccion: 'Cerrar sesión',
        onAccion: ref.read(controladorSesionProvider).cerrarSesion,
      ),
    );
  }
}
