import 'package:flutter/material.dart';
import 'cell_base.dart';

/// ID: 3 - 森林 (阻挡视线，不阻挡移动)
class ForestCell extends Cell {
  const ForestCell()
    : super(
        name: 'Forest',
        blocksVision: true,
        blocksMovement: false,
        canStand: true,
      );

  @override
  void render(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.green.withOpacity(0.6);
    // 画一个圆代表树
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;
    canvas.drawCircle(center, radius, paint);
  }
}
