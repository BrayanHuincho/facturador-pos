import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';

class FabNavItem {
  const FabNavItem({required this.icon, required this.label, this.activeIcon});
  final IconData icon;
  final IconData? activeIcon;
  final String label;
}

class FabNavBar extends StatelessWidget {
  const FabNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.fabIcon,
    required this.fabLabel,
    required this.onFab,
    this.fabBadge,
  }) : assert(onFab == null || items.length % 2 == 0);

  final List<FabNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final IconData fabIcon;
  final String fabLabel;
  final VoidCallback? onFab;

  final int? fabBadge;

  static const double _lift = 18;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final half = items.length ~/ 2;

    Widget item(int i) => Expanded(
      child: _NavButton(
        item: items[i],
        active: i == currentIndex,
        onTap: () => onTap(i),
      ),
    );

    return SizedBox(
      height: AppV2.navHeight + bottom + _lift,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: _lift,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(top: BorderSide(color: p.border)),
                boxShadow: p.isDark
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x0D0E1B33),
                          blurRadius: 12,
                          offset: Offset(0, -2),
                        ),
                      ],
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: Row(
                  children: [
                    for (var i = 0; i < half; i++) item(i),
                    if (onFab != null)
                      const SizedBox(width: AppV2.fab + AppSpace.x4),
                    for (var i = half; i < items.length; i++) item(i),
                  ],
                ),
              ),
            ),
          ),
          if (onFab != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _CentralFab(
                  icon: fabIcon,
                  label: fabLabel,
                  onTap: onFab!,
                  badge: fabBadge,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final FabNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = active ? p.brand : p.navInactive;
    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? (item.activeIcon ?? item.icon) : item.icon,
              size: 24,
              color: c,
            ),
            const SizedBox(height: AppSpace.x1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.15),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: c,
                    height: 1.1,
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

class _CentralFab extends StatelessWidget {
  const _CentralFab({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: AppV2.fab + AppSpace.x4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: AppV2.fab,
                    height: AppV2.fab,
                    decoration: BoxDecoration(
                      color: p.brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.brand, width: 4),
                      boxShadow: p.isDark
                          ? null
                          : const [
                              BoxShadow(
                                color: Color(0x331F5BD8),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Icon(icon, color: p.onBrand, size: 26),
                  ),
                  if ((badge ?? 0) > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.danger,
                          borderRadius: AppRadii.pillAll,
                          border: Border.all(color: p.surface, width: 2),
                        ),
                        child: Text(
                          '$badge',
                          style: TextStyle(
                            color: p.isDark
                                ? AppColors.ink
                                : AppColors.neutral0,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: 1.15),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.brand,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FabNavRail extends StatelessWidget {
  const FabNavRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.fabIcon,
    required this.fabLabel,
    required this.onFab,
    this.fabBadge,
  });

  final List<FabNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final IconData fabIcon;
  final String fabLabel;
  final VoidCallback? onFab;
  final int? fabBadge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 96,
          height: double.infinity,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: AppSpace.x4),
                if (onFab != null)
                  _CentralFab(
                    icon: fabIcon,
                    label: fabLabel,
                    onTap: onFab!,
                    badge: fabBadge,
                  ),
                const SizedBox(height: AppSpace.x4),
                for (var i = 0; i < items.length; i++)
                  SizedBox(
                    height: 72,
                    child: _NavButton(
                      item: items[i],
                      active: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
