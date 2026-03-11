import 'dart:ui';

import '../framework/map/cell.dart';

/// ID: 5 — 水体
///
/// 使用 Plastic015A 材质。
class WaterCell extends Cell {
  const WaterCell();

  @override
  int get id => 5;

  @override
  String get name => '水体';

  static const String imagePath = 'Plastic015A/Plastic015A_1K-PNG_Color.png';
  static const Color color = Color(0xFF42A5F5);
}
