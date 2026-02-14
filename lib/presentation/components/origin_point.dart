import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class OriginPoint extends PositionComponent {
  @override
  void render(Canvas canvas) {
    const double length = 10.0;
    final paint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // 绘制十字
    canvas.drawLine(const Offset(-length, 0), const Offset(length, 0), paint);
    canvas.drawLine(const Offset(0, -length), const Offset(0, length), paint);

    // 绘制中心实心点
    canvas.drawCircle(Offset.zero, 3.0, Paint()..color = Colors.yellow);
  }
}
