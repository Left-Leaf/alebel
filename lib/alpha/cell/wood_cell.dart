import 'dart:ui';

import '../framework/map/cell.dart';

/// ID: 2 — 木质地形
///
/// 使用 Wood090A 木材材质。
class WoodCell extends Cell {
  const WoodCell();

  @override
  int get id => 2;

  @override
  String get name => '木质';

  static const String imagePath = 'Wood090A/Wood090A_1K-PNG_Color.png';
  static const Color color = Color(0xFF8D6E63);
}
