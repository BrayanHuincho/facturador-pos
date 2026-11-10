import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/design_system.dart';

class EstadoCargando extends StatelessWidget {
  const EstadoCargando({this.mensaje, super.key});

  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    final texto = mensaje;
    if (texto == null) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Skeleton.list(rows: 6),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpace.x4),
          Text(texto, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    required this.titulo,
    this.mensaje,
    this.icono = LucideIcons.inbox,
    this.textoAccion,
    this.onAccion,
    super.key,
  });

  final String titulo;
  final String? mensaje;
  final IconData icono;
  final String? textoAccion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) => EmptyState(
    title: titulo,
    message: mensaje,
    icon: icono,
    actionLabel: textoAccion,
    onAction: onAccion,
  );
}

class EstadoError extends StatelessWidget {
  const EstadoError({
    required this.error,
    this.titulo = 'No se pudo cargar',
    this.onReintentar,
    super.key,
  });

  final Object error;
  final String titulo;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) =>
      ErrorView(error: error, title: titulo, onRetry: onReintentar);
}

class ContenidoAsync<T> extends StatelessWidget {
  const ContenidoAsync({
    required this.valor,
    required this.builder,
    this.onReintentar,
    this.mensajeCarga,
    super.key,
  });

  final AsyncValue<T> valor;
  final Widget Function(T datos) builder;
  final VoidCallback? onReintentar;
  final String? mensajeCarga;

  @override
  Widget build(BuildContext context) {
    if (valor.hasValue) return builder(valor.requireValue);
    if (valor.hasError) {
      return EstadoError(error: valor.error!, onReintentar: onReintentar);
    }
    return EstadoCargando(mensaje: mensajeCarga);
  }
}

void mostrarMensaje(
  BuildContext context,
  String mensaje, {
  bool error = false,
}) {
  if (error) {
    AppToast.error(context, mensaje);
  } else {
    AppToast.exito(context, mensaje);
  }
}
