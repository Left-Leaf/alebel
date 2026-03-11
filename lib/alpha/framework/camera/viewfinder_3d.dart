import 'package:flame/components.dart';

import 'camera_3d.dart';

/// 3D 取景器 — 控制通过视口看到世界的哪一部分。
///
/// 持有 [Camera3D] 变换状态（target、yaw、pitch、zoom），
/// 世界内容作为子组件添加。
///
/// 不重写 [renderTree] — 由 [Camera3DComponent] 在正确的
/// canvas 变换下调用本组件的 renderTree。
///
/// 实现 [CoordinateTransform]，供 [Camera3DComponent] 事件路由使用，
/// 将视口局部坐标转换为世界坐标。
class Viewfinder3D extends Component implements CoordinateTransform {
  /// 3D 相机变换（等价于 Flame Viewfinder 中的 Transform2D）。
  final Camera3D transform = Camera3D();

  // ---------------------------------------------------------------------------
  // CoordinateTransform（事件命中测试）
  // ---------------------------------------------------------------------------

  @override
  Vector2? parentToLocal(Vector2 point) => transform.screenToWorld(point);

  @override
  Vector2? localToParent(Vector2 point) => transform.worldToScreen(point);

  // ---------------------------------------------------------------------------
  // 委托属性
  // ---------------------------------------------------------------------------

  Vector2 get target => transform.target;

  set target(Vector2 v) => transform.target = v;

  double get targetX => transform.targetX;

  set targetX(double v) => transform.targetX = v;

  double get targetY => transform.targetY;

  set targetY(double v) => transform.targetY = v;

  double get zoom => transform.zoom;

  set zoom(double v) => transform.zoom = v;

  double get yaw => transform.yaw;

  set yaw(double v) => transform.yaw = v;

  double get pitch => transform.pitch;

  set pitch(double v) => transform.pitch = v;

  // ---------------------------------------------------------------------------
  // 委托方法
  // ---------------------------------------------------------------------------

  void setFrom(Camera3D other) => transform.setFrom(other);

  void lerpFrom(Camera3D a, Camera3D b, double t) =>
      transform.lerpFrom(a, b, t);

  Camera3D snapshot() => transform.clone();

  Vector2 worldToScreen(Vector2 point, {Vector2? output}) =>
      transform.worldToScreen(point, output: output);

  Vector2 screenToWorld(Vector2 point, {Vector2? output}) =>
      transform.screenToWorld(point, output: output);

  Vector2 screenToWorldDirection(double sx, double sy) =>
      transform.screenToWorldDirection(sx, sy);
}
