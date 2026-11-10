import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/design_system.dart';

class CampoTexto extends StatefulWidget {
  const CampoTexto({
    required this.etiqueta,
    this.controller,
    this.validator,
    this.ayuda,
    this.teclado,
    this.accionTeclado,
    this.esClave = false,
    this.habilitado = true,
    this.soloLectura = false,
    this.icono,
    this.sufijo,
    this.formateadores,
    this.longitudMaxima,
    this.lineas = 1,
    this.autofill,
    this.capitalizacion = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final String etiqueta;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final String? ayuda;
  final TextInputType? teclado;
  final TextInputAction? accionTeclado;
  final bool esClave;
  final bool habilitado;
  final bool soloLectura;
  final IconData? icono;
  final Widget? sufijo;
  final List<TextInputFormatter>? formateadores;
  final int? longitudMaxima;
  final int lineas;
  final Iterable<String>? autofill;
  final TextCapitalization capitalizacion;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  bool _oculto = true;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tema = Theme.of(context);
    final sufijo = widget.esClave
        ? IconButton(
            tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
            icon: Icon(
              _oculto ? LucideIcons.eye : LucideIcons.eyeOff,
              size: AppSizes.iconMd,
              color: p.textMuted,
            ),
            onPressed: () => setState(() => _oculto = !_oculto),
          )
        : widget.sufijo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.etiqueta,
          style: tema.textTheme.labelMedium?.copyWith(color: p.text),
        ),
        const SizedBox(height: AppSpace.x1 + 2),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          keyboardType: widget.teclado,
          textInputAction: widget.accionTeclado,
          obscureText: widget.esClave && _oculto,
          enableSuggestions: !widget.esClave,
          autocorrect: !widget.esClave,
          enabled: widget.habilitado,
          readOnly: widget.soloLectura,
          inputFormatters: widget.formateadores,
          maxLength: widget.longitudMaxima,
          maxLines: widget.esClave ? 1 : widget.lineas,
          autofillHints: widget.autofill,
          textCapitalization: widget.capitalizacion,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          style: tema.textTheme.bodyLarge,
          decoration: InputDecoration(
            helperText: widget.ayuda,
            helperMaxLines: 3,
            counterText: '',
            prefixIcon: widget.icono == null
                ? null
                : Icon(widget.icono, size: AppSizes.iconMd, color: p.textMuted),
            suffixIcon: sufijo,
            suffixIconConstraints: const BoxConstraints(
              minWidth: AppSizes.minTouch,
              minHeight: AppSizes.minTouch,
            ),
          ),
        ),
      ],
    );
  }
}

class CampoDinero extends StatelessWidget {
  const CampoDinero({
    required this.etiqueta,
    this.controller,
    this.validator,
    this.ayuda,
    this.onChanged,
    super.key,
  });

  final String etiqueta;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final String? ayuda;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => CampoTexto(
    etiqueta: etiqueta,
    controller: controller,
    validator: validator,
    ayuda: ayuda,
    onChanged: onChanged,
    teclado: const TextInputType.numberWithOptions(decimal: true),
    formateadores: [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
    ],
    sufijo: Padding(
      padding: const EdgeInsets.all(AppSpace.x3),
      child: Text(
        'S/',
        style: TextStyle(
          color: context.palette.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
