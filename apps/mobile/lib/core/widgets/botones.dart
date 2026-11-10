import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

class BotonPrimario extends StatelessWidget {
  const BotonPrimario({
    required this.texto,
    required this.onPressed,
    this.icono,
    this.cargando = false,
    this.expandido = true,
    super.key,
  });

  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final bool cargando;
  final bool expandido;

  @override
  Widget build(BuildContext context) => AppButton(
    label: texto,
    icon: icono,
    loading: cargando,
    expand: expandido,
    size: AppButtonSize.large,
    onPressed: onPressed,
  );
}

class BotonSecundario extends StatelessWidget {
  const BotonSecundario({
    required this.texto,
    required this.onPressed,
    this.icono,
    this.cargando = false,
    this.expandido = true,
    super.key,
  });

  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final bool cargando;
  final bool expandido;

  @override
  Widget build(BuildContext context) => AppButton(
    label: texto,
    icon: icono,
    loading: cargando,
    expand: expandido,
    variant: AppButtonVariant.secondary,
    onPressed: onPressed,
  );
}
