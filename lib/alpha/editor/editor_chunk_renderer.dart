import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../framework/map/map_chunk.dart';
import 'editor_state.dart';

/// 单区块渲染器
///
/// 纯渲染组件，不处理任何输入事件。
/// 优先使用材质图渲染格子，回退到纯色填充。
class EditorChunkRenderer extends PositionComponent {
  final int chunkX;
  final int chunkY;
  final EditorState editorState;

  EditorChunkRenderer({
    required this.chunkX,
    required this.chunkY,
    required this.editorState,
  }) : super(
          size: Vector2.all(MapChunk.size * editorState.cellSize),
          position: Vector2(
            chunkX * MapChunk.size * editorState.cellSize,
            chunkY * MapChunk.size * editorState.cellSize,
          ),
        );

  static final _gridPaint = ui.Paint()
    ..color = const ui.Color(0x33FFFFFF)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 0.5;

  static final _chunkBorderPaint = ui.Paint()
    ..color = const ui.Color(0x66FFFFFF)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static final _chunkHoverPaint = ui.Paint()
    ..color = const ui.Color(0xFFFFD54F)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2.0;

  static final _cellSelectedPaint = ui.Paint()
    ..color = const ui.Color(0xFFFF5722)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2.0;

  static final _imagePaint = ui.Paint();

  @override
  void render(ui.Canvas canvas) {
    final map = editorState.editableMap;
    if (map == null) return;

    final chunk = map.getChunk(chunkX, chunkY);
    if (chunk == null) return;

    final cs = editorState.cellSize;
    final colors = editorState.cellColors;
    final images = editorState.cellImages;
    final selectedPos = editorState.selectedCellPos;

    for (var ly = 0; ly < MapChunk.size; ly++) {
      for (var lx = 0; lx < MapChunk.size; lx++) {
        final cell = chunk.getCell(lx, ly);
        final dstRect = ui.Rect.fromLTWH(lx * cs, ly * cs, cs, cs);

        // 优先材质图，回退纯色
        final cellImage = images[cell.id];
        if (cellImage != null) {
          // 平铺材质：每个格子取材质图的对应区域
          final srcRect = ui.Rect.fromLTWH(
            lx * cs,
            ly * cs,
            cs,
            cs,
          );
          canvas.drawImageRect(cellImage, srcRect, dstRect, _imagePaint);
        } else {
          final color = colors[cell.id] ?? const ui.Color(0xFF888888);
          canvas.drawRect(dstRect, ui.Paint()..color = color);
        }

        // 网格线
        canvas.drawRect(dstRect, _gridPaint);

        // 选中格高亮
        final wx = chunkX * MapChunk.size + lx;
        final wy = chunkY * MapChunk.size + ly;
        if (selectedPos != null &&
            selectedPos.$1 == wx &&
            selectedPos.$2 == wy) {
          canvas.drawRect(dstRect.deflate(1), _cellSelectedPaint);
        }
      }
    }

    // 区块边框
    final hovered = editorState.hoveredChunk;
    final isHovered =
        hovered != null && hovered.$1 == chunkX && hovered.$2 == chunkY;
    canvas.drawRect(
      size.toRect(),
      isHovered ? _chunkHoverPaint : _chunkBorderPaint,
    );
  }
}

/// 空区块占位渲染器
///
/// 在已加载区块的四周绘制虚线边框和 "+" 标记，
/// 提示用户点击此处可以扩展世界。
class GhostChunkRenderer extends PositionComponent {
  final int chunkX;
  final int chunkY;
  final EditorState editorState;

  GhostChunkRenderer({
    required this.chunkX,
    required this.chunkY,
    required this.editorState,
  }) : super(
          size: Vector2.all(MapChunk.size * editorState.cellSize),
          position: Vector2(
            chunkX * MapChunk.size * editorState.cellSize,
            chunkY * MapChunk.size * editorState.cellSize,
          ),
        );

  static final _ghostBorderPaint = ui.Paint()
    ..color = const ui.Color(0x33FFFFFF)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static final _ghostHoverBorderPaint = ui.Paint()
    ..color = const ui.Color(0xAAFFD54F)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2.0;

  static final _ghostHoverFillPaint = ui.Paint()
    ..color = const ui.Color(0x0DFFD54F);

  static final _plusPaint = ui.Paint()
    ..color = const ui.Color(0x44FFFFFF)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2.0;

  static final _plusHoverPaint = ui.Paint()
    ..color = const ui.Color(0xAAFFD54F)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2.5;

  @override
  void render(ui.Canvas canvas) {
    final hovered = editorState.hoveredChunk;
    final isHovered =
        hovered != null && hovered.$1 == chunkX && hovered.$2 == chunkY;

    final rect = size.toRect();

    if (isHovered) {
      canvas.drawRect(rect, _ghostHoverFillPaint);
      _drawDashedRect(canvas, rect, _ghostHoverBorderPaint);
    } else {
      _drawDashedRect(canvas, rect, _ghostBorderPaint);
    }

    // "+" 标记
    final center = rect.center;
    final armLen = size.x * 0.08;
    final paint = isHovered ? _plusHoverPaint : _plusPaint;
    canvas.drawLine(
      ui.Offset(center.dx - armLen, center.dy),
      ui.Offset(center.dx + armLen, center.dy),
      paint,
    );
    canvas.drawLine(
      ui.Offset(center.dx, center.dy - armLen),
      ui.Offset(center.dx, center.dy + armLen),
      paint,
    );
  }

  void _drawDashedRect(ui.Canvas canvas, ui.Rect rect, ui.Paint paint) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    _drawDashedLine(
        canvas, rect.topLeft, rect.topRight, paint, dashLen, gapLen);
    _drawDashedLine(
        canvas, rect.topRight, rect.bottomRight, paint, dashLen, gapLen);
    _drawDashedLine(
        canvas, rect.bottomRight, rect.bottomLeft, paint, dashLen, gapLen);
    _drawDashedLine(
        canvas, rect.bottomLeft, rect.topLeft, paint, dashLen, gapLen);
  }

  void _drawDashedLine(ui.Canvas canvas, ui.Offset start, ui.Offset end,
      ui.Paint paint, double dashLen, double gapLen) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final totalLen = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
    if (totalLen == 0) return;

    final ux = dx / totalLen;
    final uy = dy / totalLen;
    var pos = 0.0;
    while (pos < totalLen) {
      final segEnd = (pos + dashLen).clamp(0.0, totalLen);
      canvas.drawLine(
        ui.Offset(start.dx + ux * pos, start.dy + uy * pos),
        ui.Offset(start.dx + ux * segEnd, start.dy + uy * segEnd),
        paint,
      );
      pos += dashLen + gapLen;
    }
  }
}
