import 'dart:ui';

import 'package:flame/components.dart';

import 'camera_3d.dart';
import 'viewfinder_3d.dart';
import 'viewport_3d.dart';

/// 3D 正交相机组件 — 编排 [Viewfinder3D]、[Viewport3D] 和 HUD 的渲染与事件路由。
///
/// 结构类似 Flame [CameraComponent]：
/// - [viewfinder]：持有 [Camera3D]，控制看到世界的哪一部分；世界内容添加为其子组件
/// - [viewport]：定义视口窗口（大小、裁剪、分辨率缩放）；HUD 添加为其子组件
///
/// 渲染管线：
/// 1. 定位视口（position / anchor）
/// 2. 裁剪（[Viewport3D.clip]）
/// 3. 视口变换（[Viewport3D.transformCanvas]，如分辨率缩放）
/// 4. 相机变换（[Camera3D.transformMatrix]）→ 世界内容
/// 5. HUD（无相机变换）
///
/// 为向后兼容，保留对 [viewfinder] 的委托属性（target、zoom 等），
/// 使 `camera.zoom = ...` 等调用继续有效。
class Camera3DComponent extends Component {
  Camera3DComponent({
    Viewport3D? viewport,
    Viewfinder3D? viewfinder,
    List<Component>? hudComponents,
  })  : viewport = (viewport ?? MaxViewport3D())
          ..addAll(hudComponents ?? []),
        viewfinder = viewfinder ?? Viewfinder3D() {
    addAll([this.viewport, this.viewfinder]);
  }

  /// 视口 — HUD 子组件添加于此。
  final Viewport3D viewport;

  /// 取景器 — 世界内容添加于此。
  final Viewfinder3D viewfinder;

  // ---------------------------------------------------------------------------
  // 渲染 — 手动编排，不调 super.renderTree
  // ---------------------------------------------------------------------------

  @override
  void renderTree(Canvas canvas) {
    if (viewport.isReady) {
      final vs = viewport.virtualSize;
      viewfinder.transform.setViewportSize(vs.x, vs.y);
    }

    canvas.save();

    // 1. 视口定位
    canvas.translate(
      viewport.position.x - viewport.anchor.x * viewport.size.x,
      viewport.position.y - viewport.anchor.y * viewport.size.y,
    );

    // 2. 裁剪 + 视口变换
    canvas.save();
    viewport.clip(canvas);
    viewport.transformCanvas(canvas);

    // 3. 相机变换 → 世界内容
    canvas.save();
    canvas.transform(viewfinder.transform.transformMatrix);
    viewfinder.renderTree(canvas);
    canvas.restore();

    // 4. HUD（在视口变换下，但无相机变换）
    viewport.renderTree(canvas);
    canvas.restore();

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // 事件路由 — 手动分发到 viewport → viewfinder 两条链路
  // ---------------------------------------------------------------------------

  @override
  Iterable<Component> componentsAtLocation<T>(
    T locationContext,
    List<T>? nestedContexts,
    T? Function(CoordinateTransform, T) transformContext,
    bool Function(Component, T) checkContains,
  ) sync* {
    // screen → viewport local
    final viewportPoint = transformContext(viewport, locationContext);
    if (viewportPoint == null) return;

    // HUD hit-test（viewport 子组件）
    yield* viewport.componentsAtLocation(
      viewportPoint,
      nestedContexts,
      transformContext,
      checkContains,
    );

    // viewport local → world（通过 viewfinder 变换）
    if (checkContains(viewport, viewportPoint)) {
      final worldPoint = transformContext(viewfinder, viewportPoint);
      if (worldPoint == null) return;

      yield* viewfinder.componentsAtLocation(
        worldPoint,
        nestedContexts,
        transformContext,
        checkContains,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 委托属性 — 转发到 viewfinder，保持向后兼容
  // ---------------------------------------------------------------------------

  /// 相机变换状态（委托到 [viewfinder.transform]）。
  Camera3D get transform => viewfinder.transform;

  Vector2 get target => viewfinder.target;

  set target(Vector2 v) => viewfinder.target = v;

  double get targetX => viewfinder.targetX;

  set targetX(double v) => viewfinder.targetX = v;

  double get targetY => viewfinder.targetY;

  set targetY(double v) => viewfinder.targetY = v;

  double get zoom => viewfinder.zoom;

  set zoom(double v) => viewfinder.zoom = v;

  double get yaw => viewfinder.yaw;

  set yaw(double v) => viewfinder.yaw = v;

  double get pitch => viewfinder.pitch;

  set pitch(double v) => viewfinder.pitch = v;

  // ---------------------------------------------------------------------------
  // 委托方法
  // ---------------------------------------------------------------------------

  void setFrom(Camera3D other) => viewfinder.setFrom(other);

  void lerpFrom(Camera3D a, Camera3D b, double t) =>
      viewfinder.lerpFrom(a, b, t);

  Camera3D snapshot() => viewfinder.snapshot();

  Vector2 worldToScreen(Vector2 point, {Vector2? output}) =>
      viewfinder.worldToScreen(point, output: output);

  Vector2 screenToWorld(Vector2 point, {Vector2? output}) =>
      viewfinder.screenToWorld(point, output: output);

  Vector2 screenToWorldDirection(double sx, double sy) =>
      viewfinder.screenToWorldDirection(sx, sy);
}
