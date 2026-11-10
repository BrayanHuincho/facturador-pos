import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';

class CategoryChipItem<T> {
  const CategoryChipItem({required this.id, required this.label, this.count});
  final T? id;
  final String label;
  final int? count;
}

class CategoryChips<T> extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpace.x4),
  });

  final List<CategoryChipItem<T>> items;
  final T? selected;
  final ValueChanged<T?> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x2),
        itemBuilder: (context, i) {
          final it = items[i];
          final on = it.id == selected;
          return Semantics(
            selected: on,
            button: true,
            child: Material(
              color: on ? p.brand : p.surface,
              shape: StadiumBorder(
                side: BorderSide(color: on ? p.brand : p.border),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onSelected(it.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        it.label,
                        style: text.labelLarge?.copyWith(
                          fontSize: 14,
                          color: on ? p.onBrand : p.text,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      if (it.count != null) ...[
                        const SizedBox(width: AppSpace.x1 + 2),
                        Text(
                          '${it.count}',
                          style: text.labelMedium?.copyWith(
                            color: on
                                ? p.onBrand.withValues(alpha: 0.8)
                                : p.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
