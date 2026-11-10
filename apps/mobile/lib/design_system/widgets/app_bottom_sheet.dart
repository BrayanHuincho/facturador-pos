import 'package:flutter/material.dart';

import '../tokens/dimens.dart';

abstract final class AppBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? footer,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: isDismissible,
      constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
      builder: (context) =>
          _SheetBody(title: title, footer: footer, child: child),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.child, this.footer});

  final String title;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x5,
              0,
              AppSpace.x5,
              AppSpace.x3,
            ),
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.x5),
              child: child,
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.x5,
                AppSpace.x4,
                AppSpace.x5,
                AppSpace.x5,
              ),
              child: footer,
            )
          else
            const SizedBox(height: AppSpace.x5),
        ],
      ),
    );
  }
}
