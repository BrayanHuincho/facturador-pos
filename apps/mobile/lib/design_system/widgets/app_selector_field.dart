import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';
import 'app_selector_sheet.dart';
import 'icon_chip.dart';

class AppSelectorField<T> extends StatelessWidget {
  const AppSelectorField({
    super.key,
    required this.titulo,
    required this.opciones,
    required this.onChanged,
    this.initialValue,
    this.etiqueta,
    this.icono,
    this.ayuda,
    this.validator,
    this.textoVacio = 'Elegir',
  });

  final String titulo;
  final List<AppSelectorOption<T>> opciones;
  final ValueChanged<T?>? onChanged;
  final T? initialValue;
  final String? etiqueta;
  final IconData? icono;
  final String? ayuda;
  final FormFieldValidator<T>? validator;
  final String textoVacio;

  AppSelectorOption<T>? _opcionDe(T? valor) {
    for (final opcion in opciones) {
      if (opcion.value == valor) return opcion;
    }
    return null;
  }

  Future<void> _abrir(BuildContext context, FormFieldState<T> campo) async {
    final indiceActual = opciones.indexWhere((o) => o.value == campo.value);
    final elegido = await AppSelectorSheet.show<int>(
      context,
      title: titulo,
      selected: indiceActual,
      options: [
        for (final (indice, opcion) in opciones.indexed)
          AppSelectorOption<int>(
            value: indice,
            label: opcion.label,
            subtitle: opcion.subtitle,
            leading:
                opcion.leading ??
                (icono == null ? null : IconChip(icono, size: 36)),
          ),
      ],
    );
    if (elegido == null) return;
    final valor = opciones[elegido].value;
    campo.didChange(valor);
    onChanged?.call(valor);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tema = Theme.of(context).textTheme;
    final habilitado = onChanged != null;
    return FormField<T>(
      initialValue: initialValue,
      validator: validator,
      builder: (campo) {
        final opcion = _opcionDe(campo.value);
        final contenido = InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            enabled: habilitado,
            errorText: campo.errorText,
            helperText: ayuda,
            helperMaxLines: 2,
            prefixIcon: icono == null
                ? null
                : Icon(icono, size: AppSizes.iconMd, color: p.textMuted),
            suffixIcon: Icon(
              LucideIcons.chevronDown,
              size: AppSizes.iconMd,
              color: p.textMuted,
            ),
          ),
          child: Text(
            opcion?.label ?? textoVacio,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tema.bodyLarge?.copyWith(
              color: opcion == null || !habilitado ? p.textMuted : p.text,
            ),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (etiqueta != null) ...[
              Text(etiqueta!, style: tema.labelMedium?.copyWith(color: p.text)),
              const SizedBox(height: AppSpace.x1 + 2),
            ],
            Semantics(
              button: true,
              label: etiqueta ?? titulo,
              value: opcion?.label,
              child: InkWell(
                borderRadius: AppRadii.mdAll,
                onTap: habilitado ? () => _abrir(context, campo) : null,
                child: contenido,
              ),
            ),
          ],
        );
      },
    );
  }
}
