import 'dart:ui';

import 'package:flame/components.dart';

import '../../framework/projected_bounds.dart';
import '../../framework/scene_map.dart';
import 'world_cell.dart';
import 'world_demo_scene.dart';

class WorldDemoMap extends SceneMap<WorldDemoScene> {
  static const int totalSize = 40;
  static const int borderWidth = 10;
  static const int explorableSize = totalSize - borderWidth * 2;

  static const double cellPx = WorldCell.cellSize;
  static const double worldSize = totalSize * cellPx;
  static const double borderPx = borderWidth * cellPx;

  Rect get innerBounds => Rect.fromLTWH(
        borderPx,
        borderPx,
        explorableSize * cellPx,
        explorableSize * cellPx,
      );

  Rect get outerBounds => Rect.fromLTWH(0, 0, worldSize, worldSize);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    for (int r = 0; r < totalSize; r++) {
      for (int c = 0; c < totalSize; c++) {
        final explorable = r >= borderWidth &&
            r < totalSize - borderWidth &&
            c >= borderWidth &&
            c < totalSize - borderWidth;

        camera.add(
          WorldCell(col: c, row: r, isExplorable: explorable)
            ..position = Vector2(
              c * cellPx,
              r * cellPx,
            ),
        );
      }
    }

    camera.addAll([
      _BoundsMarker(innerBounds, const Color(0xFFFFD700))
        ..add(ProjectedAxisAlignedBoundingBox()),
      _BoundsMarker(outerBounds, const Color(0xFFFF4444))
        ..add(ProjectedAxisAlignedBoundingBox()),
    ]);

    final center = Vector2(worldSize / 2, worldSize / 2);
    camera.setToTopDown(target: center, zoom: 5);
  }
}

class _BoundsMarker extends Component with HasProjectedBounds {
  @override
  final Rect bounds;

  @override
  final Color boundsColor;

  _BoundsMarker(this.bounds, this.boundsColor);
}
