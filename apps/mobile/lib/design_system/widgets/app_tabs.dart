import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';

class AppTabs extends StatelessWidget {
  const AppTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.onBrand = false,
    this.expand = true,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final bool onBrand;

  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final active = onBrand ? p.onHeader : p.brand;
    final idle = onBrand ? p.onHeader.withValues(alpha: 0.72) : p.navInactive;

    Widget tab(int i) {
      final on = i == index;
      return Semantics(
        selected: on,
        button: true,
        child: InkWell(
          onTap: () => onChanged(i),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: on ? active : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              tabs[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelLarge?.copyWith(
                color: on ? active : idle,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: onBrand ? null : Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            expand ? Expanded(child: tab(i)) : tab(i),
        ],
      ),
    );
  }
}
