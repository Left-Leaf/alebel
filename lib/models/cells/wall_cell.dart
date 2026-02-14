import 'package:flutter/material.dart';
import 'cell_base.dart';

/// ID: 1 - 墙壁 (阻挡视线和移动)
class WallCell extends Cell {
  const WallCell()
    : super(
        name: 'Wall',
        blocksVision: true,
        blocksMovement: true,
        canStand: false,
      );

  @override
  void render(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey;
    // 稍微缩小一点以显示间隔
    final rect = Offset.zero & size;
    canvas.drawRect(rect.deflate(2), paint);
    
    // 画一个简单的砖块纹理示意
    final paintLine = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paintLine);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paintLine);
  }
}
