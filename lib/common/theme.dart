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
}
