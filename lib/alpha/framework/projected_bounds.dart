import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import 'scene_map.dart';

/// 声明一个世界坐标矩形，用于投影 AABB 可视化。
///
/// 混入到 [Camera3DComponent] 的子组件上，配合 [ProjectedAxisAlignedBoundingBox] 使用。
///
/// ```dart
/// class MyMarker extends Component with HasProjectedBounds {
///   @override
///   Rect get bounds => Rect.fromLTWH(0, 0, 100, 100);
///
///   @override
///   Color get boundsColor => Color(0xFFFF0000);
/// }
///
/// camera.add(MyMarker()..add(ProjectedBoundsOverlay()));
/// ```
mixin HasProjectedBounds on Component {
  /// 世界坐标系中的矩形范围。
  Rect get bounds;

  /// AABB 边框颜色，子类可覆写。
  Color get boundsColor => const Color(0xFFFFFFFF);
}

/// 为父级 [HasProjectedBounds] 组件绘制屏幕空间投影 AABB 边框。
///
/// 添加为 [HasProjectedBounds] 组件的子组件。
/// 通过 [HasAncestor] 自动获取祖先 [SceneMap] 的相机，
/// 在 render 中先逆变换回屏幕空间再绘制 AABB。
class ProjectedAxisAlignedBoundingBox extends Component
    with HasAncestor<SceneMap>, ParentIsA<HasProjectedBounds> {
  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void render(Canvas canvas) {
    final cam = ancestor.camera;
    final m = cam.transform.transformMatrix;

    final aabb = _projectAABB(parent.bounds, m);

    canvas.save();
    _applyInverse(canvas, m);
    _paint.color = parent.boundsColor;
    canvas.drawRect(aabb, _paint);
    canvas.restore();
  }

  /// 将世界矩形的 4 角投影到屏幕空间，返回 AABB。
  Rect _projectAABB(Rect world, Float64List m) {
    final m00 = m[0], m10 = m[1], m01 = m[4], m11 = m[5];
    final tx = m[12], ty = m[13];

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final corner in [
      (world.left, world.top),
      (world.right, world.top),
      (world.right, world.bottom),
      (world.left, world.bottom),
    ]) {
      final sx = m00 * corner.$1 + m01 * corner.$2 + tx;
      final sy = m10 * corner.$1 + m11 * corner.$2 + ty;
      minX = math.min(minX, sx);
      minY = math.min(minY, sy);
      maxX = math.max(maxX, sx);
      maxY = math.max(maxY, sy);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// 对 canvas 应用当前相机矩阵的逆变换，回到屏幕空间。
  void _applyInverse(Canvas canvas, Float64List m) {
    final m00 = m[0], m10 = m[1], m01 = m[4], m11 = m[5];
    final tx = m[12], ty = m[13];

    final det = m00 * m11 - m01 * m10;
    if (det.abs() < 1e-10) return;
    final d = 1.0 / det;

    final inv = Float64List(16);
    inv[0] = m11 * d;
    inv[1] = -m10 * d;
    inv[4] = -m01 * d;
    inv[5] = m00 * d;
    inv[10] = 1;
    inv[15] = 1;
    inv[12] = -(inv[0] * tx + inv[4] * ty);
    inv[13] = -(inv[1] * tx + inv[5] * ty);
    canvas.transform(inv);
  }
}
