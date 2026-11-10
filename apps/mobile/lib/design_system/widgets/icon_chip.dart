import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';

class IconChip extends StatelessWidget {
  const IconChip(
    this.icon, {
    super.key,
    this.color,
    this.size = AppV2.iconChip,
    this.iconSize,
    this.child,
  });

  final IconData? icon;
  final Color? color;
  final double size;
  final double? iconSize;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = p.tono(color ?? p.brand);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: p.alfaTinte),
        borderRadius: BorderRadius.circular(
          size * AppV2.iconChipRadius / AppV2.iconChip,
        ),
      ),
      child: child ?? Icon(icon, color: c, size: iconSize ?? size * 0.5),
    );
  }
}

abstract final class CategoryColors {
  static const List<Color> values = [
    Color(0xFF1F5BD8),
    Color(0xFF0F8A5F),
    Color(0xFFC2410C),
    Color(0xFF7C3AED),
    Color(0xFFBE185D),
    Color(0xFF0E7490),
    Color(0xFFA16207),
  ];

  static Color of(String? key) {
    if (key == null || key.isEmpty) return values.first;
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return values[h % values.length];
  }
}

class ProductThumb extends StatelessWidget {
  const ProductThumb({
    super.key,
    required this.nombre,
    this.size = AppV2.thumb,
    this.dimmed = false,
    this.categoria,
    this.imagenUrl,
    this.imagenLocal,
  });

  @visibleForTesting
  static ImageProvider Function(String url)? imagenDePrueba;

  final String nombre;

  final String? categoria;

  final String? imagenUrl;

  final Uint8List? imagenLocal;

  final double size;

  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chip = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(
          size * AppV2.iconChipRadius / AppV2.iconChip,
        ),
      ),
      child: Icon(
        LucideIcons.image,
        size: size * 0.4,
        color: p.textMuted.withValues(alpha: 0.45),
      ),
    );
    final foto = _foto(context, chip);
    if (foto == null) return ExcludeSemantics(child: chip);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          size * AppV2.iconChipRadius / AppV2.iconChip,
        ),
        child: SizedBox.square(
          dimension: size,
          child: dimmed
              ? Opacity(
                  opacity: 0.55,
                  child: ColorFiltered(colorFilter: _grises, child: foto),
                )
              : foto,
        ),
      ),
    );
  }

  static const _grises = ColorFilter.matrix([
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  Widget? _foto(BuildContext context, Widget chip) {
    final ancho = (size * MediaQuery.devicePixelRatioOf(context)).round();
    Widget error(BuildContext _, Object _, StackTrace? _) => chip;
    if (imagenLocal != null) {
      return Image.memory(
        imagenLocal!,
        fit: BoxFit.cover,
        cacheWidth: ancho,
        errorBuilder: error,
      );
    }
    final url = imagenUrl;
    if (url == null || url.isEmpty) return null;
    final prueba = imagenDePrueba;
    if (prueba != null) {
      return Image(image: prueba(url), fit: BoxFit.cover, errorBuilder: error);
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: ancho,
      errorBuilder: error,
      loadingBuilder: (_, imagen, progreso) => progreso == null ? imagen : chip,
    );
  }
}

class AvatarIniciales extends StatelessWidget {
  const AvatarIniciales({
    super.key,
    required this.nombre,
    this.size = 48,
    this.onLight = false,
    this.fotoUrl,
  });

  final String nombre;
  final String? fotoUrl;
  final double size;
  final bool onLight;

  static String iniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'[\s@._-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    final a = partes.first.characters.first;
    final b = partes.length > 1 ? partes[1].characters.first : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = fotoUrl;
    if (url != null) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _iniciales(context),
        ),
      );
    }
    return _iniciales(context);
  }

  Widget _iniciales(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onLight ? p.brandSoft : p.onHeader.withValues(alpha: 0.18),
          border: Border.all(
            color: onLight
                ? p.brand.withValues(alpha: 0.2)
                : p.onHeader.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Text(
          iniciales(nombre),
          style: TextStyle(
            color: onLight ? p.brand : p.onHeader,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36,
            height: 1,
          ),
        ),
      ),
    );
  }
}
