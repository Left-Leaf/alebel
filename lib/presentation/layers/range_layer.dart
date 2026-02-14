import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/map/board.dart'; // 为了使用 Position typedef
import '../components/cell_component.dart';

class RangeLayer extends PositionComponent {
  final Map<Position, Color> _renderData = {};

  RangeLayer();

  void updateRanges(List<({int x, int y, Color color})> data) {
    _renderData.clear();
    for (final item in data) {
      _renderData[(x: item.x, y: item.y)] = item.color;
    }
  }

  void clear() {
    _renderData.clear();
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final entry in _renderData.entries) {
      final pos = entry.key;
      final color = entry.value;
      
      paint.color = color;
      
      final rect = Rect.fromLTWH(
        pos.x * CellComponent.cellSize,
        pos.y * CellComponent.cellSize,
        CellComponent.cellSize,
        CellComponent.cellSize,
      );
      // 稍微缩小一点，让格子之间有缝隙，更好看
      canvas.drawRect(rect.deflate(2), paint);
    }
  }
}
