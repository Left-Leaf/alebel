import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../camera/viewfinder_3d.dart';
import '../world.dart';

/// 投影包围盒 debug 可视化混入。
///
/// 混入到 [SceneWorld] 子树中的任意 Component 上，开启 `debugMode` 即可显示
/// [bounds] 经相机投影后的屏幕空间 AABB 边框。
///
/// 需要同时混入 [HasAncestor]<[SceneWorld]> 以获取相机。
///
/// [bounds] 使用**局部坐标系**，mixin 内部自动计算到世界坐标的偏移。
///
/// ```dart
/// class MyBoard extends PositionComponent
///     with HasAncestor<SceneMap>, ProjectedAxisAlignedBoundingBox {
///   @override
///   Rect get bounds => Rect.fromLTWH(0, 0, width, height);
///
///   @override
///   Color get boundsColor => Color(0xFF00FF00);
/// }
///
/// // 在 Map 中：
/// board.debugMode = true;
/// ```
mixin ProjectedAxisAlignedBoundingBox on PositionComponent, HasAncestor<Viewfinder3D> {
  /// 局部坐标系中的矩形范围。
  Rect get bounds;

  /// AABB 边框颜色。
  Color get boundsColor => const Color(0xFFFFFFFF);

  final Paint _aabbPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  /// 当前组件的 [bounds] 经相机投影后的屏幕空间 AABB。
  Rect get projectedBounds {
    final m = ancestor.transform.transformMatrix;
    final offset = _viewfinderOffset();
    final worldBounds = bounds.translate(offset.x, offset.y);
    return _projectAABB(worldBounds, m);
  }

  @override
  void renderDebugMode(Canvas canvas) {
    super.renderDebugMode(canvas);

    final aabb = projectedBounds;
    final m = ancestor.transform.transformMatrix;
    final offset = _viewfinderOffset();

    canvas.save();
    if (offset.x != 0 || offset.y != 0) {
      canvas.translate(-offset.x, -offset.y);
    }
    _applyCameraInverse(canvas, m);
    _aabbPaint.color = boundsColor;
    canvas.drawRect(aabb, _aabbPaint);
    canvas.restore();
  }

  /// 累计从当前组件到 viewfinder 的所有 [PositionComponent] 位置偏移。
  ///
  /// 对每个 [PositionComponent]，有效偏移 = position − anchor × size
  /// （忽略旋转和缩放）。
  Vector2 _viewfinderOffset() {
    final viewfinder = ancestor;
    var x = 0.0, y = 0.0;
    Component? c = this;
    while (c != null && c != viewfinder) {
      if (c is PositionComponent) {
        x += c.position.x - c.anchor.x * c.size.x;
        y += c.position.y - c.anchor.y * c.size.y;
      }
      c = c.parent;
    }
    return Vector2(x, y);
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

  /// 对 canvas 应用相机矩阵的逆变换，回到视口空间。
  void _applyCameraInverse(Canvas canvas, Float64List m) {
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
