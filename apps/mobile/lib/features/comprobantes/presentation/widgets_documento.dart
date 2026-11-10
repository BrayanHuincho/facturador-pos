export 'package:facturador_pos/core/errores/errores.dart' show mensajeDeError;

import 'package:facturador_pos/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../domain/comprobante.dart';

void avisar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.codigo});

  final String codigo;

  @override
  Widget build(BuildContext context) {
    final estado = EstadoDocumento.desde(codigo);
    final p = context.palette;
    final (Color color, Color fondo, IconData icono) = switch (estado) {
      EstadoDocumento.aceptado => (
        p.success,
        p.successSoft,
        LucideIcons.circleCheck,
      ),
      EstadoDocumento.observado => (
        p.warning,
        p.warningSoft,
        LucideIcons.triangleAlert,
      ),
      EstadoDocumento.rechazado => (
        p.danger,
        p.dangerSoft,
        LucideIcons.circleX,
      ),
      EstadoDocumento.error => (
        p.danger,
        p.dangerSoft,
        LucideIcons.circleAlert,
      ),
      EstadoDocumento.anulado => (p.textMuted, p.surfaceMuted, LucideIcons.ban),
      EstadoDocumento.noAplica => (
        p.textMuted,
        p.surfaceMuted,
        LucideIcons.receiptText,
      ),
      _ => (p.brand, p.brandSoft, LucideIcons.clock),
    };
    final etiqueta = estado == EstadoDocumento.desconocido && codigo.isNotEmpty
        ? codigo
        : estado.etiqueta;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x2 + 2,
        vertical: AppSpace.x1,
      ),
      decoration: BoxDecoration(color: fondo, borderRadius: AppRadii.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: AppSpace.x1 + 2),
          Flexible(
            child: Text(
              etiqueta,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class FilaDato extends StatelessWidget {
  const FilaDato(
    this.etiqueta,
    this.valor, {
    super.key,
    this.destacado = false,
  });

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final estilo = destacado ? tema.titleMedium : tema.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(valor, style: estilo, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class SeccionDocumento extends StatelessWidget {
  const SeccionDocumento({
    super.key,
    required this.titulo,
    required this.children,
  });

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.x3),
    child: SectionCard(
      title: titulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.mensaje, this.alReintentar});

  final String mensaje;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) => EmptyState(
    title: mensaje,
    icon: alReintentar == null ? LucideIcons.inbox : LucideIcons.cloudOff,
    actionLabel: alReintentar == null ? null : 'Reintentar',
    onAction: alReintentar,
  );
}
