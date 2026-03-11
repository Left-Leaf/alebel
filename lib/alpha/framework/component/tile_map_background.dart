import 'dart:ui';

import 'package:flame/components.dart';

import '../camera/camera_3d.dart';
import '../camera/viewfinder_3d.dart';

/// 瓦片地图背景组件。
///
/// 通过 `(col, row) → imagePath` 的映射描述每格瓦片，支持稀疏分布：
/// 世界边界内外的任意网格位置都可以放置瓦片，未映射的位置不渲染。
///
/// 每帧根据相机可见区域反算世界空间 AABB，只绘制落入该区域且存在映射的瓦片。
/// 网格原点为世界坐标 (0, 0)，瓦片坐标为左上角。
///
/// ```dart
/// camera.viewfinder.add(
///   TileMapBackground(
///     tileSize: 160,
///     tiles: {
///       (0, 0): 'grass.png',
///       (1, 0): 'dirt.png',
///       (0, 1): 'stone.png',
///       (-1, 0): 'sand.png', // 世界边界外也可放置
///     },
///   ),
/// );
/// ```
class TileMapBackground extends Component with HasGameReference, HasAncestor<Viewfinder3D> {
  /// 单个瓦片在世界空间中的尺寸（宽高相同）。
  final double tileSize;

  /// 瓦片映射：`(col, row)` → 图片资源路径（相对于 assets/images/）。
  final Map<(int, int), String> tiles;

  final Map<String, _TileEntry> _atlas = {};
  final Paint _paint = Paint()..filterQuality = FilterQuality.low;

  TileMapBackground({required this.tileSize, required this.tiles, super.priority = -1});

  @override
  Future<void> onLoad() async {
    // 收集去重的图片路径，批量加载
    final paths = tiles.values.toSet();
    for (final path in paths) {
      final image = await game.images.load(path);
      _atlas[path] = _TileEntry(
        image: image,
        src: Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final Camera3D cam = ancestor.transform;
    final Vector2 vc = cam.viewportCenter;
    final double w = vc.x * 2;
    final double h = vc.y * 2;
    if (w == 0 || h == 0) return;

    // 屏幕四角 → 世界坐标
    final c0 = cam.screenToWorld(Vector2(0, 0));
    final c1 = cam.screenToWorld(Vector2(w, 0));
    final c2 = cam.screenToWorld(Vector2(w, h));
    final c3 = cam.screenToWorld(Vector2(0, h));

    // 可见世界区域 AABB
    double minX = c0.x, maxX = c0.x, minY = c0.y, maxY = c0.y;
    for (final c in [c1, c2, c3]) {
      if (c.x < minX) minX = c.x;
      if (c.x > maxX) maxX = c.x;
      if (c.y < minY) minY = c.y;
      if (c.y > maxY) maxY = c.y;
    }

    // 可见瓦片索引范围
    final startCol = (minX / tileSize).floor();
    final endCol = (maxX / tileSize).ceil();
    final startRow = (minY / tileSize).floor();
    final endRow = (maxY / tileSize).ceil();

    for (int r = startRow; r < endRow; r++) {
      for (int c = startCol; c < endCol; c++) {
        final path = tiles[(c, r)];
        if (path == null) continue;
        final entry = _atlas[path]!;
        final dst = Rect.fromLTWH(c * tileSize, r * tileSize, tileSize, tileSize);
        canvas.drawImageRect(entry.image, entry.src, dst, _paint);
      }
    }
  }
}

class _TileEntry {
  final Image image;
  final Rect src;

  const _TileEntry({required this.image, required this.src});
}
