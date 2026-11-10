import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/cobro.dart';

class MedioPagoLogo extends StatelessWidget {
  const MedioPagoLogo(this.medio, {super.key, this.size = 40});

  final MedioPago medio;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radio = BorderRadius.circular(size * 0.28);
    final Widget contenido = switch (medio) {
      MedioPago.yape => Image.asset(
        'assets/marcas/yape.png',
        fit: BoxFit.cover,
      ),
      MedioPago.plin => ColoredBox(
        color: p.isDark ? p.plate : Colors.transparent,
        child: Image.asset('assets/marcas/plin.png', fit: BoxFit.contain),
      ),
      MedioPago.tarjeta => DecoratedBox(
        decoration: BoxDecoration(
          color: p.plate,
          border: Border.all(color: p.isDark ? p.plate : p.border),
          borderRadius: radio,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size * 0.1,
            vertical: size * 0.16,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Flexible(child: SvgPicture.asset('assets/marcas/visa.svg')),
              Flexible(child: SvgPicture.asset('assets/marcas/mastercard.svg')),
            ],
          ),
        ),
      ),
      MedioPago.efectivo => _Tinte(p.success, LucideIcons.banknote, size),
      MedioPago.transferencia => _Tinte(p.brand, LucideIcons.landmark, size),
      MedioPago.deposito => _Tinte(p.warning, LucideIcons.piggyBank, size),
      MedioPago.otro => _Tinte(p.textMuted, LucideIcons.wallet, size),
    };
    return Semantics(
      label: medio.etiqueta,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(borderRadius: radio, child: contenido),
      ),
    );
  }
}

class _Tinte extends StatelessWidget {
  const _Tinte(this.color, this.icono, this.size);

  final Color color;
  final IconData icono;
  final double size;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color.withValues(alpha: context.palette.isDark ? 0.17 : 0.12),
    child: Center(
      child: Icon(icono, color: color, size: size * 0.52),
    ),
  );
}

class WhatsAppLogo extends StatelessWidget {
  const WhatsAppLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/marcas/whatsapp.svg',
    width: size,
    height: size,
    semanticsLabel: 'WhatsApp',
  );
}
