import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

class DemoCell extends PositionComponent
    with TapCallbacks, HoverCallbacks {
  static const double cellSize = 4;

  final int col;
  final int row;

  bool _hovered = false;
  bool _selected = false;

  @override
  bool get isHovered => _hovered;
  bool get isSelected => _selected;

  set selected(bool value) {
    _selected = value;
  }

  DemoCell({required this.col, required this.row})
      : super(
          size: Vector2.all(cellSize),
          anchor: Anchor.topLeft,
        );

  static const _colorNormal = Color(0xFF3A3A4A);
  static const _colorHovered = Color(0xFF5A5A7A);
  static const _colorSelected = Color(0xFF2A7AB5);
  static const _colorSelectedHovered = Color(0xFF4FC3F7);

  static final _borderPaint = Paint()
      ..color = const Color(0xFF555566)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.2;

  static final _selectedBorderPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;

  @override
  void onHoverEnter() => _hovered = true;

  @override
  void onHoverExit() => _hovered = false;

  @override
  void onTapUp(TapUpEvent event) {
    _selected = !_selected;
  }

  @override
  void render(Canvas canvas) {
    final Color fill;
    if (_selected && _hovered) {
      fill = _colorSelectedHovered;
    } else if (_selected) {
      fill = _colorSelected;
    } else if (_hovered) {
      fill = _colorHovered;
    } else {
      fill = _colorNormal;
    }

    final rect = size.toRect();
    canvas.drawRect(rect, Paint()..color = fill);
    canvas.drawRect(rect, _selected ? _selectedBorderPaint : _borderPaint);
  }
}
