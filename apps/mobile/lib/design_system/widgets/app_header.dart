import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/colors.dart';
import '../tokens/dimens.dart';

const SystemUiOverlayStyle appHeaderOverlay = SystemUiOverlayStyle(
  statusBarColor: AppColors.header,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

SystemUiOverlayStyle appHeaderOverlayDe(AppPalette p) =>
    appHeaderOverlay.copyWith(statusBarColor: p.header);

class AppSystemUi extends StatelessWidget {
  const AppSystemUi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: p.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: p.surface,
        systemNavigationBarDividerColor: p.border,
        systemNavigationBarIconBrightness: p.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: child,
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.extraBottomPadding = 0,
    this.automaticBack = true,
  });

  final String? title;

  final Widget? titleWidget;
  final String? subtitle;

  final Widget? leading;
  final List<Widget> actions;

  final Widget? bottom;

  final double extraBottomPadding;
  final bool automaticBack;

  static Widget sliver({
    Key? key,
    required String title,
    List<Widget> actions = const [],
    Widget? bottom,
    double bottomHeight = 0,
    bool automaticBack = true,
  }) => _AppHeaderSliver(
    key: key,
    title: title,
    actions: actions,
    bottom: bottom,
    bottomHeight: bottomHeight,
    automaticBack: automaticBack,
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canPop =
        automaticBack &&
        ((ModalRoute.of(context)?.canPop ?? false) || AppBackScope.of(context));
    final lead = leading ?? (canPop ? const AppHeaderBack() : null);
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: appHeaderOverlayDe(context.palette),
      child: Material(
        color: context.palette.header,
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    lead == null ? AppSpace.x4 : AppSpace.x1,
                    AppSpace.x2,
                    AppSpace.x2,
                    AppSpace.x2,
                  ),
                  child: Row(
                    children: [
                      ?lead,
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: lead == null ? 0 : AppSpace.x1,
                          ),
                          child:
                              titleWidget ??
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      title ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.headlineSmall?.copyWith(
                                        color: context.palette.onHeader,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (subtitle != null)
                                    Text(
                                      subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.bodySmall?.copyWith(
                                        color: context.palette.onHeader
                                            .withValues(alpha: 0.82),
                                      ),
                                    ),
                                ],
                              ),
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.x4,
                    0,
                    AppSpace.x4,
                    AppSpace.x3,
                  ),
                  child: bottom,
                ),
              if (extraBottomPadding > 0) SizedBox(height: extraBottomPadding),
            ],
          ),
        ),
      ),
    );
  }
}

class AppBackScope extends InheritedWidget {
  const AppBackScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppBackScope>() != null;

  @override
  bool updateShouldNotify(AppBackScope oldWidget) => false;
}

class AppHeaderBack extends StatelessWidget {
  const AppHeaderBack({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Atrás',
    color: context.palette.onHeader,
    icon: const Icon(LucideIcons.arrowLeft),
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
  );
}

class AppHeaderAction extends StatelessWidget {
  const AppHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;

  final String? label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return IconButton(
        tooltip: tooltip,
        color: context.palette.onHeader,
        icon: Icon(icon),
        onPressed: onPressed,
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: context.palette.onHeader,
        backgroundColor: context.palette.onHeader.withValues(alpha: 0.14),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.x3),
        minimumSize: const Size(0, 40),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label!, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _AppHeaderSliver extends StatelessWidget {
  const _AppHeaderSliver({
    super.key,
    required this.title,
    required this.actions,
    required this.bottom,
    required this.bottomHeight,
    required this.automaticBack,
  });

  final String title;
  final List<Widget> actions;
  final Widget? bottom;
  final double bottomHeight;
  final bool automaticBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canPop =
        automaticBack &&
        ((ModalRoute.of(context)?.canPop ?? false) || AppBackScope.of(context));
    return SliverAppBar(
      pinned: true,
      floating: true,
      systemOverlayStyle: appHeaderOverlay,
      backgroundColor: context.palette.header,
      foregroundColor: context.palette.onHeader,
      surfaceTintColor: Colors.transparent,
      shape: const Border(),
      automaticallyImplyLeading: false,
      leading: canPop ? const AppHeaderBack() : null,
      titleSpacing: canPop ? 0 : AppSpace.x4,
      title: Text(
        title,
        style: text.headlineSmall?.copyWith(
          color: context.palette.onHeader,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        ...actions,
        const SizedBox(width: AppSpace.x2),
      ],
      bottom: bottom == null
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(bottomHeight + AppSpace.x3),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.x4,
                  0,
                  AppSpace.x4,
                  AppSpace.x3,
                ),
                child: SizedBox(height: bottomHeight, child: bottom),
              ),
            ),
    );
  }
}
