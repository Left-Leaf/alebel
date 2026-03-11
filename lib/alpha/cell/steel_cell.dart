import 'dart:ui';

import '../framework/map/cell.dart';

/// ID: 4 — 钢质地形
///
/// 使用 Metal046B 金属材质。
class SteelCell extends Cell {
  const SteelCell();

  @override
  int get id => 4;

  @override
  String get name => '钢质';

  static const String imagePath = 'Metal046B/Metal046B_1K-PNG_Color.png';
  static const Color color = Color(0xFF607D8B);
}
