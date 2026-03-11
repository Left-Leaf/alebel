import 'dart:ui';

import 'package:flame/components.dart';

import '../camera/camera_3d.dart';
import '../camera/viewfinder_3d.dart';

/// 无限平铺背景组件。
///
/// 每帧根据相机可见区域反算世界空间 AABB，只绘制落入该区域的瓦片。
/// 平铺原点为世界坐标 (0, 0)，瓦片坐标为左上角。
///
/// 使用方式：添加到 `camera.viewfinder`，设置 [priority] 为负值以渲染在其他内容之下。
///
/// ```dart
/// camera.viewfinder.add(
///   TiledBackground(imagePath: 'backdrop/tile.png', tileSize: 160),
/// );
/// ```
class TiledBackground extends Component
    with HasGameReference, HasAncestor<Viewfinder3D> {
  /// 瓦片图片资源路径（相对于 assets/images/）。
  final String imagePath;

  /// 单个瓦片在世界空间中的尺寸（宽高相同）。
  final double tileSize;

  late final Image _image;
  late final Rect _src;
  final Paint _paint = Paint()..filterQuality = FilterQuality.low;

  TiledBackground({
    required this.imagePath,
    required this.tileSize,
    super.priority = -1,
  });

  @override
  Future<void> onLoad() async {
    _image = await game.images.load(imagePath);
    _src = Rect.fromLTWH(
      0,
      0,
      _image.width.toDouble(),
      _image.height.toDouble(),
    );
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

    // 瓦片索引范围（左上角坐标）
    final startCol = (minX / tileSize).floor();
    final endCol = (maxX / tileSize).ceil();
    final startRow = (minY / tileSize).floor();
    final endRow = (maxY / tileSize).ceil();

    for (int r = startRow; r < endRow; r++) {
      for (int c = startCol; c < endCol; c++) {
        final dst = Rect.fromLTWH(
          c * tileSize,
          r * tileSize,
          tileSize,
          tileSize,
        );
        canvas.drawImageRect(_image, _src, dst, _paint);
      }
    }
  }
}
