import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/cobro.dart';
import 'medio_pago_logo.dart';

Future<void> mostrarQrGrande(
  BuildContext context, {
  required MedioPago medio,
  required String url,
  Decimal? monto,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _QrGrande(medio: medio, url: url, monto: monto),
  ),
);

class _QrGrande extends StatelessWidget {
  const _QrGrande({required this.medio, required this.url, this.monto});

  final MedioPago medio;
  final String url;
  final Decimal? monto;

  static const _tinta = AppColors.ink;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _tinta,
        iconTheme: const IconThemeData(color: _tinta),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final lado = math
                .min(c.maxWidth - AppSpace.x8, c.maxHeight * 0.62)
                .clamp(160.0, 520.0);
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.x4,
                    0,
                    AppSpace.x4,
                    AppSpace.x6,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          MedioPagoLogo(medio, size: 36),
                          const SizedBox(width: AppSpace.x2),
                          Text(
                            medio.etiqueta,
                            style: t.titleLarge?.copyWith(
                              color: _tinta,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (monto != null) ...[
                        const SizedBox(height: AppSpace.x3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: MoneyText(
                            monto!,
                            size: MoneySize.display,
                            color: _tinta,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpace.x5),
                      Image.network(
                        url,
                        width: lado,
                        height: lado,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, _, _) => SizedBox.square(
                          dimension: lado,
                          child: const Icon(
                            LucideIcons.qrCode,
                            size: 64,
                            color: _tinta,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BloqueQrCobro extends StatelessWidget {
  const BloqueQrCobro({
    required this.medio,
    required this.url,
    required this.monto,
    super.key,
  });

  final MedioPago medio;
  final String url;
  final Decimal monto;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    void ampliar() =>
        mostrarQrGrande(context, medio: medio, url: url, monto: monto);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: AppRadii.lgAll,
            onTap: ampliar,
            child: Container(
              height: 240,
              padding: const EdgeInsets.all(AppSpace.x3),
              decoration: BoxDecoration(
                color: p.plate,
                borderRadius: AppRadii.lgAll,
                border: Border.all(color: p.border),
              ),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, _, _) =>
                    const Icon(LucideIcons.qrCode, size: 64),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: ampliar,
            icon: Icon(
              LucideIcons.maximize,
              size: AppSizes.iconMd,
              color: p.brand,
            ),
            label: Text('Mostrar QR de ${medio.etiqueta} en grande'),
          ),
        ],
      ),
    );
  }
}
