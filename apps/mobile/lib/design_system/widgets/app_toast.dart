import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';

abstract final class AppToast {
  static const Duration duracionConAccion = Duration(seconds: 5);

  static const Duration duracion = Duration(milliseconds: 2500);

  static OverlayEntry? _actual;

  static void exito(
    BuildContext context,
    String mensaje, {
    ToastAccion? accion,
  }) => para(context).exito(mensaje, accion: accion);

  static void error(
    BuildContext context,
    String mensaje, {
    ToastAccion? accion,
  }) => para(context).error(mensaje, accion: accion);

  static AppToaster para(BuildContext context) => AppToaster._(
    context.mounted ? Overlay.maybeOf(context, rootOverlay: true) : null,
  );

  static void _mostrar(
    OverlayState? overlay,
    String mensaje, {
    required bool error,
    ToastAccion? accion,
  }) {
    if (overlay == null || !overlay.mounted) return;
    _quitar();
    late final OverlayEntry entrada;
    entrada = OverlayEntry(
      builder: (_) => _Toast(
        mensaje: mensaje,
        error: error,
        accion: accion,
        onFin: () {
          if (identical(_actual, entrada)) _quitar();
        },
      ),
    );
    _actual = entrada;
    overlay.insert(entrada);
  }

  static void _quitar() {
    final entrada = _actual;
    _actual = null;
    if (entrada != null && entrada.mounted) entrada.remove();
  }
}

class ToastAccion {
  const ToastAccion(this.etiqueta, this.alTocar);

  final String etiqueta;
  final VoidCallback alTocar;
}

class AppToaster {
  const AppToaster._(this._overlay);

  final OverlayState? _overlay;

  void exito(String mensaje, {ToastAccion? accion}) =>
      AppToast._mostrar(_overlay, mensaje, error: false, accion: accion);

  void error(String mensaje, {ToastAccion? accion}) =>
      AppToast._mostrar(_overlay, mensaje, error: true, accion: accion);
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.mensaje,
    required this.error,
    this.accion,
    required this.onFin,
  });

  final String mensaje;
  final bool error;
  final ToastAccion? accion;
  final VoidCallback onFin;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  static const _transicion = AppMotion.base;
  late final AnimationController _c;
  late final Animation<double> _visible;

  @override
  void initState() {
    super.initState();
    final permanencia = widget.accion == null
        ? AppToast.duracion
        : AppToast.duracionConAccion;
    _c =
        AnimationController(
            vsync: this,
            duration: permanencia + _transicion * 2,
          )
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) widget.onFin();
          })
          ..forward();
    final t = _transicion.inMilliseconds.toDouble();
    final p = permanencia.inMilliseconds.toDouble();
    _visible = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: AppMotion.standard)),
        weight: t,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: p),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: t,
      ),
    ]).animate(_c);
  }

  void _cerrar() {
    final inicioSalida =
        1 - _transicion.inMilliseconds / _c.duration!.inMilliseconds;
    if (_c.value < inicioSalida) {
      _c
        ..value = inicioSalida
        ..forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mq = MediaQuery.of(context);
    final color = widget.error ? p.danger : p.success;
    final fondo = widget.error ? p.dangerSoft : p.successSoft;
    final abajo = math.max(
      mq.viewPadding.bottom + AppV2.navHeight + AppSpace.x4,
      mq.viewInsets.bottom + AppSpace.x3,
    );
    final sinAnimar = mq.disableAnimations;
    return Positioned(
      left: AppSpace.x4,
      right: AppSpace.x4,
      bottom: abajo,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AnimatedBuilder(
            animation: _visible,
            builder: (context, child) => Opacity(
              opacity: _visible.value,
              child: Transform.translate(
                offset: Offset(
                  0,
                  sinAnimar ? 0 : (1 - _visible.value) * AppSpace.x3,
                ),
                child: child,
              ),
            ),
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Material(
                type: MaterialType.transparency,
                child: GestureDetector(
                  onTap: _cerrar,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppV2.cardRadius),
                      border: Border.all(color: color.withValues(alpha: 0.28)),
                      boxShadow: p.sombraFlotante,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.x3),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: fondo,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.error
                                  ? LucideIcons.circleAlert
                                  : LucideIcons.check,
                              size: 18,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: AppSpace.x3),
                          Expanded(
                            child: Text(
                              widget.mensaje,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (widget.accion case final accion?)
                            TextButton(
                              onPressed: () {
                                accion.alTocar();
                                _cerrar();
                              },
                              child: Text(accion.etiqueta),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
