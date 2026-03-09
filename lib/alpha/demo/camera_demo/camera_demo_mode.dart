import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';

import '../../framework/camera_3d.dart';
import '../../framework/camera_3d_component.dart';
import '../../framework/mode.dart';
import 'camera_demo_scene.dart';

class CameraDemoMode extends Mode<CameraDemoScene> with KeyboardHandler {
  static const double _animDuration = 0.6;
  static const double _zoomFactor = 1.1;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 20.0;

  bool _isTopDown = true;
  Camera3D? _fromCamera;
  Camera3D? _toCamera;
  double _animProgress = 1.0;

  @override
  String get modeName => 'default';

  Camera3DComponent get _camera => parent.sceneMap.camera;

  @override
  void update(double dt) {
    super.update(dt);
    if (_animProgress >= 1.0) return;

    _animProgress = (_animProgress + dt / _animDuration).clamp(0.0, 1.0);
    final t = Curves.easeInOutCubic.transform(_animProgress);
    _camera.lerpFrom(_fromCamera!, _toCamera!, t);
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final delta = info.scrollDelta.global.y;
    if (delta == 0) return;

    final multiplier = delta < 0 ? _zoomFactor : 1 / _zoomFactor;
    _camera.zoom = (_camera.zoom * multiplier).clamp(_minZoom, _maxZoom);
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      _isTopDown = !_isTopDown;
      _fromCamera = _camera.snapshot();
      _toCamera = _isTopDown
          ? Camera3D.topDown(target: Vector2.zero(), zoom: 5)
          : Camera3D.isometric(target: Vector2.zero(), zoom: 5);
      _animProgress = 0.0;
      return false;
    }
    return true;
  }
}
