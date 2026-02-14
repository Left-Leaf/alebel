import 'package:alebel/game/alebel_game.dart';
import 'package:alebel/core/map/cell_state.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class CellComponent extends PositionComponent
    with TapCallbacks, HoverCallbacks, HasGameReference<AlebelGame> {
  static const double cellSize = 50.0;

  final CellState state;

  int get gridX => state.x;

  int get gridY => state.y;

  // 状态
  bool isSelected = false;

  /// 是否阻挡视线
  bool get blocksVision => state.blocksVision;

  /// 是否阻挡移动
  bool get blocksMovement => state.blocksMovement;

  /// 单位是否能驻足
  bool get canStand => state.canStand;

  CellComponent({required this.state})
    : super(
        position: Vector2((state.x + 0.5) * cellSize, (state.y + 0.5) * cellSize),
        size: Vector2.all(cellSize),
        anchor: Anchor.center,
      );

  final _borderPaint = Paint()
    ..color = const Color(0xFF444444)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final _selectedPaint = Paint()
    ..color = Colors.yellow
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  @override
  void onTapUp(TapUpEvent event) {
    game.onCellTap(this);
  }

  @override
  void onLongTapDown(TapDownEvent event) {
    game.onCellLongPress(this);
  }

  @override
  void onHoverEnter() {
    game.onCellHoverEnter(this);
  }

  @override
  void onHoverExit() {
    game.onCellHoverExit(this);
  }

  @override
  void render(Canvas canvas) {
    // 委托给 Cell 进行自定义内容的绘制
    // 传入 size.toSize()
    state.cell.render(canvas, size.toSize());

    // 绘制基础边框 (统一在 Component 层绘制，保持风格一致)
    canvas.drawRect(size.toRect(), _borderPaint);

    // 绘制选中边框
    if (isSelected) {
      // 稍微收缩一点，防止边框重叠
      final rect = size.toRect().deflate(1.0);
      canvas.drawRect(rect, _selectedPaint);
    }
  }

  // 计算格子的矩形区域，供 Overlay 使用
  // 注意：由于 Anchor 是 center，所以 rect 应该是以 position 为中心的
  Rect get rect => Rect.fromCenter(center: position.toOffset(), width: size.x, height: size.y);
}
