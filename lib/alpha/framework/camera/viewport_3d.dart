import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show protected;

/// 3D 视口基类 — 定义相机的"窗口"。
///
/// 职责：
/// - 描述视口在屏幕上的位置、大小和形状
/// - 提供裁剪（[clip]）和分辨率缩放（[transformCanvas]）
/// - 承载 HUD 子组件（屏幕固定，不受相机变换影响）
///
/// 子类实现 [clip]、[containsLocalPoint]、[onViewportResize]。
/// 由 [Camera3DComponent] 在渲染管线中调用。
abstract class Viewport3D extends Component implements CoordinateTransform {
  final Vector2 _size = Vector2.zero();
  bool _isInitialized = false;

  /// 视口在父坐标系中的位置（锚点对齐）。
  final Vector2 position = Vector2.zero();

  /// 锚点，默认左上角。
  Anchor anchor = Anchor.topLeft;

  /// 视口物理尺寸（像素）。
  Vector2 get size => _size;

  set size(Vector2 value) {
    assert(
      value.x >= 0 && value.y >= 0,
      "Viewport size cannot be negative: $value",
    );
    _size.setFrom(value);
    _isInitialized = true;
    onViewportResize();
  }

  /// 视口逻辑尺寸（用于 HUD 布局）。
  ///
  /// 默认等于 [size]；[FixedResolutionViewport3D] 返回固定分辨率。
  Vector2 get virtualSize => _size;

  /// 对 [canvas] 应用裁剪蒙版。
  ///
  /// 蒙版坐标系以视口左上角为 (0,0)，尺寸匹配 [size]。
  void clip(Canvas canvas);

  /// 将视口内部变换应用到 [canvas]（如分辨率缩放）。
  ///
  /// 默认无操作，子类按需覆写。
  void transformCanvas(Canvas canvas) {}

  /// 判断 [point]（视口局部坐标）是否在视口区域内。
  @override
  bool containsLocalPoint(Vector2 point);

  /// 视口尺寸变化后的回调。
  @protected
  void onViewportResize();

  /// 视口是否已初始化（已设置过 size）。
  bool get isReady => _isInitialized;

  // ---------------------------------------------------------------------------
  // CoordinateTransform — position/anchor 偏移
  // ---------------------------------------------------------------------------

  /// 全局（画布）坐标 → 视口局部坐标。
  Vector2 globalToLocal(Vector2 point, {Vector2? output}) {
    final x = point.x - position.x + anchor.x * _size.x;
    final y = point.y - position.y + anchor.y * _size.y;
    return (output?..setValues(x, y)) ?? Vector2(x, y);
  }

  /// 视口局部坐标 → 全局（画布）坐标。
  Vector2 localToGlobal(Vector2 point, {Vector2? output}) {
    final x = point.x + position.x - anchor.x * _size.x;
    final y = point.y + position.y - anchor.y * _size.y;
    return (output?..setValues(x, y)) ?? Vector2(x, y);
  }

  @override
  Vector2? parentToLocal(Vector2 point) => globalToLocal(point);

  @override
  Vector2? localToParent(Vector2 point) => localToGlobal(point);
}

/// 占满游戏画布的默认视口 — 不裁剪、不缩放。
class MaxViewport3D extends Viewport3D {
  MaxViewport3D({List<Component>? children}) {
    if (children != null) addAll(children);
  }

  @override
  void onLoad() {
    size = findGame()!.canvasSize;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void clip(Canvas canvas) {}

  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onViewportResize() {}
}
