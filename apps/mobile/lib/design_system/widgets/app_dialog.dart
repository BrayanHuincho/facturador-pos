import 'package:flutter/material.dart';

import '../tokens/dimens.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.icon,
    this.scrollable = false,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? icon;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: icon,
    title: title,
    content: content,
    actions: actions,
    scrollable: scrollable,
    titlePadding: const EdgeInsets.fromLTRB(
      AppSpace.x6,
      AppSpace.x6,
      AppSpace.x6,
      AppSpace.x3,
    ),
    contentPadding: const EdgeInsets.fromLTRB(
      AppSpace.x6,
      AppSpace.x2,
      AppSpace.x6,
      AppSpace.x4,
    ),
    actionsPadding: const EdgeInsets.fromLTRB(
      AppSpace.x4,
      0,
      AppSpace.x4,
      AppSpace.x4,
    ),
  );
}
