import 'dart:ui';

import '../framework/map/cell.dart';

/// ID: 3 — 石质地形
///
/// 使用 Rock060 岩石材质。
class StoneCell extends Cell {
  const StoneCell();

  @override
  int get id => 3;

  @override
  String get name => '石质';

  static const String imagePath = 'Rock060/Rock060_1K-PNG_Color.png';
  static const Color color = Color(0xFF78909C);
}
