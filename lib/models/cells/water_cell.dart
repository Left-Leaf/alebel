import 'package:flutter/material.dart';
import 'cell_base.dart';

/// ID: 2 - 水域 (阻挡移动，不阻挡视线)
class WaterCell extends Cell {
  const WaterCell()
    : super(
        name: 'Water',
        blocksVision: false,
        blocksMovement: true,
        canStand: false,
      );

  @override
  void render(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue.withOpacity(0.5);
    final rect = Offset.zero & size;
    canvas.drawRect(rect.deflate(2), paint);
  }
}
