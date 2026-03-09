import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'camera_3d.dart';

/// 3D 正交相机组件 — 类似 Flame [CameraComponent] / [Viewfinder] 的职责封装。
///
/// 将视角变换的全部功能封装为单一组件：
/// - 持有 [Camera3D] 变换状态（[transform]），等价于 Viewfinder 持有 Transform2D
/// - 在 [renderTree] 中将 3D 投影矩阵应用到自身及所有子组件的渲染
/// - 实现 [CoordinateTransform] 接口，使鼠标/触摸事件自动经过投影逆变换
/// - 当 [bounds] 非空时，自动执行 zoom 保底 + target 钳位
///
/// 约束由外部设置（通常是 Mode）：
/// ```dart
/// camera.bounds = map.outerBounds;  // 设置约束
/// camera.bounds = null;             // 移除约束
/// ```
///
/// 用法：将世界内容作为子组件添加到 Camera3DComponent，
/// 然后修改 [transform]（或使用委托属性 / 方法）驱动视角。
class Camera3DComponent extends Component implements CoordinateTransform {
  /// 3D 相机变换（等价于 Viewfinder 中的 Transform2D）。
  final Camera3D transform = Camera3D();

  /// 视口约束范围（世界坐标系）。
  ///
  /// 非空时自动约束：
  /// - **zoom 保底**：视口不超过此范围的投影区域
  /// - **target 钳位**：视口不越界
  ///
  /// 通常由 [Mode] 在 `onActivate` 时从 [SceneMap.outerBounds] 读取并设置。
  Rect? get bounds => _bounds;

  set bounds(Rect? value) {
    if (_bounds == value) return;
    _bounds = value;
    _onTransformChanged();
  }

  Rect? _bounds;

  /// 防止约束修改 transform 属性时触发重入。
  bool _constraining = false;

  Camera3DComponent() {
    transform.addListener(_onTransformChanged);
  }

  // ---------------------------------------------------------------------------
  // 渲染
  // ---------------------------------------------------------------------------

  @override
  void renderTree(Canvas canvas) {
    canvas.save();
    canvas.transform(transform.transformMatrix);
    super.renderTree(canvas);
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // CoordinateTransform（事件命中测试）
  // ---------------------------------------------------------------------------

  @override
  Vector2? parentToLocal(Vector2 point) {
    return transform.screenToWorld(point);
  }

  @override
  Vector2? localToParent(Vector2 point) {
    return transform.worldToScreen(point);
  }

  // ---------------------------------------------------------------------------
  // 委托属性 — 免去 `.transform.` 中转
  // ---------------------------------------------------------------------------

  /// 相机注视的地面点（世界坐标）。
  Vector2 get target => transform.target;

  set target(Vector2 v) => transform.target = v;

  double get targetX => transform.targetX;

  set targetX(double v) => transform.targetX = v;

  double get targetY => transform.targetY;

  set targetY(double v) => transform.targetY = v;

  /// 缩放倍率。
  double get zoom => transform.zoom;

  set zoom(double v) => transform.zoom = v;

  /// 绕垂直轴旋转（弧度），0 = 正北。
  double get yaw => transform.yaw;

  set yaw(double v) => transform.yaw = v;

  /// 俯仰角（弧度），0 = 水平，π/2 = 正上方俯视。
  double get pitch => transform.pitch;

  set pitch(double v) => transform.pitch = v;

  // ---------------------------------------------------------------------------
  // 委托方法
  // ---------------------------------------------------------------------------

  /// 设为正上方俯视。
  void setToTopDown({Vector2? target, double? zoom}) =>
      transform.setToTopDown(target: target, zoom: zoom);

  /// 设为标准等角投影。
  void setToIsometric({Vector2? target, double? zoom}) =>
      transform.setToIsometric(target: target, zoom: zoom);

  /// 从另一个 Camera3D 复制所有属性。
  void setFrom(Camera3D other) => transform.setFrom(other);

  /// 将 transform 设为 [a] 和 [b] 的线性插值。
  void lerpFrom(Camera3D a, Camera3D b, double t) => transform.lerpFrom(a, b, t);

  /// 快照当前相机状态（返回独立的 Camera3D 副本）。
  Camera3D snapshot() => transform.clone();

  /// 世界坐标 → 屏幕坐标。
  Vector2 worldToScreen(Vector2 point, {Vector2? output}) =>
      transform.worldToScreen(point, output: output);

  /// 屏幕坐标 → 世界坐标。
  Vector2 screenToWorld(Vector2 point, {Vector2? output}) =>
      transform.screenToWorld(point, output: output);

  /// 屏幕空间方向 → 世界空间方向。
  Vector2 screenToWorldDirection(double sx, double sy) => transform.screenToWorldDirection(sx, sy);

  // ---------------------------------------------------------------------------
  // 视口约束
  // ---------------------------------------------------------------------------

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isMounted) return;
    _onTransformChanged();
  }

  void _onTransformChanged() {
    if (_constraining) return;
    _constraining = true;
    _constrainCamera();
    _constraining = false;
  }

  void _constrainCamera() {
    final b = _bounds;
    if (b == null) return;

    final game = findGame();
    if (game == null) return;
    final screen = game.size;

    final minZoom = _computeMinZoom(b, screen);
    if (transform.zoom < minZoom) transform.zoom = minZoom;
    _clampTarget(b, screen);
  }

  /// 计算视口恰好装进投影平行四边形的最小 zoom。
  double _computeMinZoom(Rect bounds, Vector2 screen) {
    final cosYaw = math.cos(transform.yaw);
    final sinYaw = math.sin(transform.yaw);
    final sinPitch = math.sin(transform.pitch);

    final halfW = bounds.width / 2;
    final halfH = bounds.height / 2;

    final a1x = cosYaw * halfW;
    final a1y = -sinPitch * sinYaw * halfW;
    final b1x = sinYaw * halfH;
    final b1y = sinPitch * cosYaw * halfH;

    final d1 = (a1x * b1y - a1y * b1x).abs();
    if (d1 < 1e-10) return transform.zoom;

    final sw2 = screen.x / 2;
    final sh2 = screen.y / 2;

    final need1 = sw2 * b1y.abs() + sh2 * b1x.abs();
    final need2 = sh2 * a1x.abs() + sw2 * a1y.abs();

    return math.max(need1, need2) / d1;
  }

  /// 视口四角反投影为世界坐标 → AABB → 与 bounds 对比 → 偏移 target。
  void _clampTarget(Rect bounds, Vector2 screen) {
    final m = transform.transformMatrix;
    final m00 = m[0];
    final m10 = m[1];
    final m01 = m[4];
    final m11 = m[5];
    final tx = m[12];
    final ty = m[13];

    final det = m00 * m11 - m01 * m10;
    if (det.abs() < 1e-10) return;
    final invDet = 1.0 / det;

    final halfW = screen.x / 2;
    final halfH = screen.y / 2;

    double wMinX = double.infinity;
    double wMinY = double.infinity;
    double wMaxX = double.negativeInfinity;
    double wMaxY = double.negativeInfinity;

    for (final corner in [
      Offset(-halfW, -halfH),
      Offset(halfW, -halfH),
      Offset(halfW, halfH),
      Offset(-halfW, halfH),
    ]) {
      final dx = corner.dx - tx;
      final dy = corner.dy - ty;
      final wx = invDet * (m11 * dx - m01 * dy);
      final wy = invDet * (-m10 * dx + m00 * dy);
      wMinX = math.min(wMinX, wx);
      wMinY = math.min(wMinY, wy);
      wMaxX = math.max(wMaxX, wx);
      wMaxY = math.max(wMaxY, wy);
    }

    final shiftX = math.max(bounds.left - wMinX, 0.0) + math.min(bounds.right - wMaxX, 0.0);
    final shiftY = math.max(bounds.top - wMinY, 0.0) + math.min(bounds.bottom - wMaxY, 0.0);

    if (shiftX == 0 && shiftY == 0) return;

    transform.target = Vector2(transform.targetX + shiftX, transform.targetY + shiftY);
  }
}
