import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'viewport_3d.dart';

/// 固定逻辑分辨率视口 — 自动缩放 + 居中 + 裁剪。
///
/// 以 [resolution] 为逻辑尺寸，按等比缩放适配实际画布：
/// - 保持宽高比，取 `min(scaleX, scaleY)` 均匀缩放
/// - 居中显示，超出部分裁剪
/// - HUD 子组件使用 [resolution] 坐标系布局
///
/// ```dart
/// Camera3DComponent(
///   viewport: FixedResolutionViewport3D(resolution: Vector2(1920, 1080)),
/// )
/// ```
class FixedResolutionViewport3D extends Viewport3D {
  /// 逻辑分辨率。
  final Vector2 resolution;

  double _scale = 1.0;
  Rect _clipRect = Rect.zero;

  FixedResolutionViewport3D({
    required this.resolution,
    List<Component>? children,
  }) {
    if (children != null) addAll(children);
  }

  @override
  Vector2 get virtualSize => resolution;

  /// 当前缩放比例。
  double get scale => _scale;

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
  void onViewportResize() {
    final scaleX = size.x / resolution.x;
    final scaleY = size.y / resolution.y;
    _scale = math.min(scaleX, scaleY);

    final scaledW = resolution.x * _scale;
    final scaledH = resolution.y * _scale;
    final offsetX = (size.x - scaledW) / 2;
    final offsetY = (size.y - scaledH) / 2;
    _clipRect = Rect.fromLTWH(offsetX, offsetY, scaledW, scaledH);
  }

  @override
  void clip(Canvas canvas) {
    canvas.clipRect(_clipRect, doAntiAlias: false);
  }

  @override
  void transformCanvas(Canvas canvas) {
    canvas.translate(_clipRect.left, _clipRect.top);
    canvas.scale(_scale);
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    return point.x >= 0 &&
        point.y >= 0 &&
        point.x <= resolution.x &&
        point.y <= resolution.y;
  }

  @override
  Vector2 globalToLocal(Vector2 point, {Vector2? output}) {
    final vp = super.globalToLocal(point, output: output);
    final x = (vp.x - _clipRect.left) / _scale;
    final y = (vp.y - _clipRect.top) / _scale;
    return (output?..setValues(x, y)) ?? Vector2(x, y);
  }

  @override
  Vector2 localToGlobal(Vector2 point, {Vector2? output}) {
    final x = point.x * _scale + _clipRect.left;
    final y = point.y * _scale + _clipRect.top;
    final vp = (output?..setValues(x, y)) ?? Vector2(x, y);
    return super.localToGlobal(vp, output: output);
  }
}
