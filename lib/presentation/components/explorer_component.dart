import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../game/alebel_game.dart';
import '../../models/units/unit_base.dart';
import 'cell_component.dart';

/// Lightweight component for exploration mode.
/// Only holds a [Unit] definition reference and grid position.
/// No battle state (HP, AP, buffs, actionGauge, etc.).
class ExplorerComponent extends PositionComponent
    with HasGameReference<AlebelGame> {
  final Unit unit;
  int gridX;
  int gridY;

  int get visionRange => unit.visionRange;
  Color get color => unit.color;

  ExplorerComponent({
    required this.unit,
    required this.gridX,
    required this.gridY,
  }) : super(
          position: Vector2(
            (gridX + 0.5) * CellComponent.cellSize,
            (gridY + 0.5) * CellComponent.cellSize,
          ),
          size: Vector2.all(CellComponent.cellSize),
          anchor: Anchor.center,
        );

  @override
  void render(Canvas canvas) {
    final radius = size.x / 2 * 0.7;

    // Shadow
    canvas.drawCircle(
      Offset(size.x / 2 + 2, size.y / 2 + 2),
      radius,
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    // Body
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius,
      Paint()..color = color,
    );

    // Edge
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }
}
