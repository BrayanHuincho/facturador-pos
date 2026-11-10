import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';

class AppSearchField extends StatefulWidget {
  const AppSearchField.onBrand({
    super.key,
    this.controller,
    this.hint = 'Buscar',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
  }) : onBrandVariant = true;

  const AppSearchField.onLight({
    super.key,
    this.controller,
    this.hint = 'Buscar',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
  }) : onBrandVariant = false;

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool onBrandVariant;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  TextEditingController? _own;
  TextEditingController get _c =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  OutlineInputBorder _b(Color? c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: c == null ? BorderSide.none : BorderSide(color: c, width: w),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final onBrand = widget.onBrandVariant;
    return SizedBox(
      height: AppV2.searchHeight,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _c,
        builder: (context, v, _) => TextField(
          controller: _c,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: p.searchText),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: p.searchHint),
            filled: true,
            fillColor: onBrand ? p.searchFill : p.surface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpace.x3),
            prefixIcon: Icon(
              LucideIcons.search,
              size: AppSizes.iconMd,
              color: p.searchHint,
            ),
            suffixIcon: v.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar',
                    icon: Icon(
                      LucideIcons.x,
                      size: AppSizes.iconMd,
                      color: p.searchHint,
                    ),
                    onPressed: () {
                      _c.clear();
                      widget.onChanged?.call('');
                    },
                  ),
            border: _b(onBrand ? null : p.border),
            enabledBorder: _b(onBrand ? null : p.border),
            focusedBorder: _b(onBrand ? p.onHeader : p.brand, 2),
          ),
        ),
      ),
    );
  }
}
