import 'dart:ui';

import '../framework/map/cell.dart';

/// ID: 0 — 空白
///
/// 无材质的空白地块，使用纯色绘制。
class EmptyCell extends Cell {
  const EmptyCell();

  @override
  int get id => 0;

  @override
  String get name => '空白';

  static const Color color = Color(0xFFFFFFFF);
}
