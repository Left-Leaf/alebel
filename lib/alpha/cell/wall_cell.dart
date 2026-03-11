import 'dart:ui';

import '../framework/map/cell.dart';

/// ID: 1 — 墙体
///
/// 使用 Metal027 金属材质。
class WallCell extends Cell {
  const WallCell();

  @override
  int get id => 1;

  @override
  String get name => '墙体';

  static const String imagePath = 'Metal027/Metal027_1K-PNG_Color.png';
  static const Color color = Color(0xFF9E9E9E);
}
