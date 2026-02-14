import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../game/alebel_game.dart';

class SelectionOverlay extends PositionComponent
    with HasGameReference<AlebelGame> {
  final _selectedPaint = Paint()
    ..color = Colors.yellow
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  final _hoverBorderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  @override
  void render(Canvas canvas) {
    // 渲染悬停状态
    final hovered = game.hoveredCell;
    if (hovered != null) {
      canvas.drawRect(hovered.rect, _hoverBorderPaint);
    }

    // 渲染选中状态
    final selected = game.selectedCell;
    if (selected != null) {
      canvas.drawRect(selected.rect, _selectedPaint);
    }
  }
}
