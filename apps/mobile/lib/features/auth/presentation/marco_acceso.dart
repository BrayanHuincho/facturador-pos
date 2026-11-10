import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../design_system/design_system.dart';

class MarcoAcceso extends StatelessWidget {
  const MarcoAcceso({required this.child, this.alVolver, super.key});

  final Widget child;
  final VoidCallback? alVolver;

  static const double _banda = 150;
  static const double _barra = 72;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tablet = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final top = MediaQuery.paddingOf(context).top;

    final tarjeta = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadii.xlAll,
          border: Border.all(color: p.border),
          boxShadow: AppElevation.e2,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.x5,
            AppSpace.x6,
            AppSpace.x5,
            AppSpace.x6,
          ),
          child: child,
        ),
      ),
    );

    Widget atras({required bool blanco}) => IconButton(
      tooltip: 'Volver',
      onPressed: alVolver,
      color: blanco ? p.onHeader : p.text,
      icon: const Icon(LucideIcons.arrowLeft, size: AppSizes.iconLg),
    );

    if (!tablet) {
      return AnnotatedRegion(
        value: appHeaderOverlayDe(p),
        child: Scaffold(
          backgroundColor: p.background,
          body: SingleChildScrollView(
            child: Stack(
              children: [
                _Banda(alto: top + _banda),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.x4,
                    top,
                    AppSpace.x4,
                    AppSpace.x8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: _barra,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const MarcaFacturacion(onBrand: true, size: 38),
                            if (alVolver != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: atras(blanco: true),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.x2),
                      Center(child: tarjeta),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion(
      value: appHeaderOverlayDe(p),
      child: Scaffold(
        backgroundColor: p.background,
        body: Row(
          children: [
            const Expanded(flex: 5, child: _PanelMarca()),
            Expanded(
              flex: 6,
              child: SafeArea(
                left: false,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpace.x6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (alVolver != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: atras(blanco: false),
                          ),
                        Center(child: tarjeta),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banda extends StatelessWidget {
  const _Banda({required this.alto});

  final double alto;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: alto,
    width: double.infinity,
    child: ClipRect(
      child: ColoredBox(
        color: context.palette.header,
        child: const Stack(
          children: [
            Positioned(
              right: -70,
              top: -90,
              child: _Circulo(diametro: 240, alfa: 0.05),
            ),
            Positioned(
              left: -60,
              bottom: -80,
              child: _Circulo(diametro: 180, alfa: 0.04),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Circulo extends StatelessWidget {
  const _Circulo({required this.diametro, required this.alfa});

  final double diametro;
  final double alfa;

  @override
  Widget build(BuildContext context) => Container(
    width: diametro,
    height: diametro,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: context.palette.onHeader.withValues(alpha: alfa),
    ),
  );
}

class _PanelMarca extends StatelessWidget {
  const _PanelMarca();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final blanco = context.palette.onHeader;
    return ColoredBox(
      color: context.palette.header,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.x10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MarcaFacturacion(onBrand: true),
              const Spacer(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  'Vende, cobra y emite tu comprobante en el mismo mostrador.',
                  style: t.headlineMedium?.copyWith(color: blanco),
                ),
              ),
              const SizedBox(height: AppSpace.x3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  'Boletas y facturas electrónicas conectadas a SUNAT.',
                  style: t.bodyMedium?.copyWith(
                    color: blanco.withValues(alpha: 0.82),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.x10),
            ],
          ),
        ),
      ),
    );
  }
}

class AccesoEncabezado extends StatelessWidget {
  const AccesoEncabezado({required this.titulo, this.bajada, super.key});

  final String titulo;
  final String? bajada;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            titulo,
            style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (bajada != null) ...[
          const SizedBox(height: AppSpace.x2),
          Text(bajada!, style: t.bodyMedium?.copyWith(color: p.textMuted)),
        ],
      ],
    );
  }
}

class AvisoAcceso extends StatelessWidget {
  const AvisoAcceso({required this.mensaje, super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.x3),
        decoration: BoxDecoration(
          borderRadius: AppRadii.mdAll,
          border: Border.all(color: p.danger.withValues(alpha: 0.25)),
          color: Color.alphaBlend(p.danger.withValues(alpha: 0.07), p.surface),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.circleAlert,
              size: AppSizes.iconMd,
              color: p.danger,
            ),
            const SizedBox(width: AppSpace.x3),
            Expanded(
              child: Text(
                mensaje,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
