import 'package:flame/components.dart';
import 'package:flame/events.dart';

import 'camera/camera_3d.dart';
import 'camera/camera_3d_component.dart';
import 'scene.dart';

/// 模式基类。
///
/// 负责：
/// - 规则的制定与游戏逻辑
/// - 交互的处理
abstract class Mode extends Component with ParentIsA<Scene>, KeyboardHandler {
  /// 模式名称标识
  String get modeName;

  void onScroll(PointerScrollInfo info) {}
}

mixin CameraControl on Mode {
  // ---------------------------------------------------------------------------
  // 属性
  // ---------------------------------------------------------------------------

  /// 3D 相机组件。
  Camera3DComponent get camera => parent.camera;

  /// 视口逻辑尺寸。
  Vector2 get viewportSize => camera.viewport.virtualSize;

  /// 当前缩放倍率。
  double get zoom => camera.zoom;

  // ---------------------------------------------------------------------------
  // 相机操作
  // ---------------------------------------------------------------------------

  /// 移动相机注视点到指定世界坐标。
  void moveTo(Vector2 position) {
    camera.target = position;
  }

  /// 设置缩放倍率。
  void zoomTo(double zoom) {
    camera.zoom = zoom;
  }

  /// 设置相机角度（偏航 + 俯仰）。
  void angleTo({double? yaw, double? pitch}) {
    if (yaw != null) camera.yaw = yaw;
    if (pitch != null) camera.pitch = pitch;
  }

  /// 直接修改底层 [Camera3D] 状态。
  ///
  /// 适用于需要一次性设置多个参数或从快照恢复的场景。
  void setCamera(Camera3D state) {
    camera.transform.setFrom(state);
  }

  // ---------------------------------------------------------------------------
  // 坐标转换
  // ---------------------------------------------------------------------------

  /// 世界坐标 → 屏幕坐标。
  Vector2 worldToScreen(Vector2 point, {Vector2? output}) =>
      camera.worldToScreen(point, output: output);

  /// 屏幕坐标 → 世界坐标。
  Vector2 screenToWorld(Vector2 point, {Vector2? output}) =>
      camera.screenToWorld(point, output: output);
}

/// 相机约束混入。
///
/// 在 [CameraControl] 基础上提供视口与视角信息，并在每帧 [update]
/// 结束时以及 [onGameResize] 时自动调用 [constrain]。
/// 继承者实现 [constrain] 以定义具体的约束逻辑（如边界钳位、缩放下限）。
mixin CameraConstraint on Mode, CameraControl {
  // ---------------------------------------------------------------------------
  // 视口 / 视角信息
  // ---------------------------------------------------------------------------

  /// 游戏画布尺寸（物理像素）。
  Vector2 get screenSize => findGame()!.size;

  /// 当前相机变换状态（可读写 target / zoom / yaw / pitch）。
  Camera3D get cameraTransform => camera.transform;

  // ---------------------------------------------------------------------------
  // 约束
  // ---------------------------------------------------------------------------

  /// 约束相机参数。
  ///
  /// 每帧 [update] 结束时及 [onGameResize] 时自动调用。
  /// 实现者在此检查并修正 target、zoom 等使其满足边界条件。
  void constrain();

  @override
  void update(double dt) {
    super.update(dt);
    constrain();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isMounted) constrain();
  }
}
