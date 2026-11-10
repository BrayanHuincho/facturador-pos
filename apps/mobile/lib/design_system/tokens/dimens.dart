import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

abstract final class AppSpace {
  static const double x0_5 = 2;
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
  static const double x16 = 64;
}

abstract final class AppRadii {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

abstract final class AppElevation {
  static const List<BoxShadow> none = [];
  static const List<BoxShadow> e1 = [
    BoxShadow(color: Color(0x0F0E1B33), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> e2 = [
    BoxShadow(color: Color(0x0F0E1B33), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> e3 = [
    BoxShadow(color: Color(0x1F0E1B33), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

abstract final class AppV2 {
  static const double cardRadius = 14;
  static const double iconChip = 42;
  static const double iconChipRadius = 12;
  static const double thumb = 48;
  static const double searchHeight = 48;
  static const double fab = 60;
  static const double navHeight = 68;
}

abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration skeletonPulse = Duration(milliseconds: 1100);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}

abstract final class AppSizes {
  static const double minTouch = 48;
  static const double buttonLarge = 56;
  static const double keypadKey = 64;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double contentMaxWidth = 720;
}

abstract final class AppBreakpoints {
  static const double medium = 600;

  static const double expanded = 840;
}
