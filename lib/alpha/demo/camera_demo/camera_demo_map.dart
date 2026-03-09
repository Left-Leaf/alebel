import 'dart:ui';

import 'package:flame/components.dart';

import '../../framework/scene_map.dart';
import 'camera_demo_scene.dart';
import 'demo_cell.dart';

class CameraDemoMap extends SceneMap<CameraDemoScene> {
  static const int rows = 10;
  static const int cols = 20;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final gridWidth = cols * DemoCell.cellSize;
    final gridHeight = rows * DemoCell.cellSize;
    final offsetX = -gridWidth / 2;
    final offsetY = -gridHeight / 2;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        camera.add(
          DemoCell(col: c, row: r)
            ..position = Vector2(
              offsetX + c * DemoCell.cellSize,
              offsetY + r * DemoCell.cellSize,
            ),
        );
      }
    }

    final axisPaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 0.3;
    camera.addAll([
      RectangleComponent(
        size: Vector2(gridWidth, 0.3),
        position: Vector2.zero(),
        anchor: Anchor.center,
        paint: axisPaint,
      ),
      RectangleComponent(
        size: Vector2(0.3, gridHeight),
        position: Vector2.zero(),
        anchor: Anchor.center,
        paint: axisPaint,
      ),
    ]);

    camera.setToTopDown(zoom: 5);
  }
}
