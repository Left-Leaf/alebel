import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

class WorldCell extends PositionComponent with TapCallbacks, HoverCallbacks {
  static const double cellSize = 4;

  final int col;
  final int row;
  final bool isExplorable;

  bool _hovered = false;
  bool _selected = false;

  @override
  bool get isHovered => _hovered;
  bool get isSelected => _selected;

  WorldCell({
    required this.col,
    required this.row,
    required this.isExplorable,
  }) : super(
          size: Vector2.all(cellSize),
          anchor: Anchor.topLeft,
        );

  // 可探索区配色
  static const _explorable = Color(0xFF3E4452);
  static const _explorableHover = Color(0xFF5A5A7A);
  static const _explorableSelected = Color(0xFF2A7AB5);
  static const _explorableSelectedHover = Color(0xFF4FC3F7);

  // 边界区配色
  static const _boundary = Color(0xFF2A2A35);

  static final _borderPaint = Paint()
      ..color = const Color(0xFF555566)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.15;

  static final _selectedBorderPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;

  static final _hatchPaint = Paint()
      ..color = const Color(0xFF353540)
      ..strokeWidth = 0.15;

  @override
  void onHoverEnter() {
    if (isExplorable) _hovered = true;
  }

  @override
  void onHoverExit() => _hovered = false;

  @override
  void onTapUp(TapUpEvent event) {
    if (isExplorable) _selected = !_selected;
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();

    if (!isExplorable) {
      canvas.drawRect(rect, Paint()..color = _boundary);
      // 斜线纹理
      canvas.save();
      canvas.clipRect(rect);
      for (double d = -cellSize; d < cellSize * 2; d += 1.2) {
        canvas.drawLine(Offset(d, 0), Offset(d + cellSize, cellSize), _hatchPaint);
      }
      canvas.restore();
      canvas.drawRect(rect, _borderPaint);
      return;
    }

    final Color fill;
    if (_selected && _hovered) {
      fill = _explorableSelectedHover;
    } else if (_selected) {
      fill = _explorableSelected;
    } else if (_hovered) {
      fill = _explorableHover;
    } else {
      fill = _explorable;
    }

    canvas.drawRect(rect, Paint()..color = fill);
    canvas.drawRect(rect, _selected ? _selectedBorderPaint : _borderPaint);
  }
}
