import 'package:flutter/material.dart';

//获取当前主题的亮度
Brightness get brightness => WidgetsBinding.instance.platformDispatcher.platformBrightness;

extension ColorTheme on Color {
  Color operator |(Color other) => switch (brightness) {
    Brightness.light => this,
    Brightness.dark => other,
  };
}

/// 颜色常量
/// 所有颜色常量都以x开头，例如xFFFFFFFF表示白色，xFF000000表示黑色。
final class AlebelTheme {
  static const Color xFF000000 = Color(0xFF000000);
  static const Color xFFFFFFFF = Color(0xFFFFFFFF);

  // 高亮颜色
  static const Color highlightMoveConfirmed = Color(0x4D2196F3); // blue alpha 0.3
  static const Color highlightMoveUncertain = Color(0x262196F3); // blue alpha 0.15
  static const Color highlightAttack = Color(0x4DF44336);        // red alpha 0.3

  // 飘字颜色
  static const Color damageText = Color(0xFFFF4444);
  static const Color healText = Color(0xFF44FF44);
  static const Color deathText = Color(0xFFAAAAAA);
  static const Color buffAppliedText = Color(0xFFFFD740);
  static const Color buffRemovedText = Color(0xFF90A4AE);
  static const Color victoryText = Color(0xFFFFD700);
  static const Color defeatText = Color(0xFFFF3333);
}
