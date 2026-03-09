import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';

import '../../framework/camera_3d.dart';
import '../../framework/camera_3d_component.dart';
import '../../framework/mode.dart';
import 'world_demo_map.dart';
import 'world_demo_scene.dart';

class WorldDemoMode extends Mode<WorldDemoScene> with KeyboardHandler {
  static const double _baseMoveSpeed = 80;
  static const double _animDuration = 0.6;
  static const double _zoomFactor = 1.1;
  static const double _maxZoom = 20.0;

  final Set<LogicalKeyboardKey> _pressed = {};

  bool _isTopDown = true;
  Camera3D? _fromCamera;
  Camera3D? _toCamera;
  double _animProgress = 1.0;

  @override
  String get modeName => 'default';

  WorldDemoMap get _map => parent.sceneMap as WorldDemoMap;
  Camera3DComponent get _camera => _map.camera;

  @override
  Future<void> onActivate() async {
    _camera.bounds = _map.outerBounds;
  }

  @override
  Future<void> onDeactivate() async {
    _camera.bounds = null;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 视角切换动画
    if (_animProgress < 1.0) {
      _animProgress = (_animProgress + dt / _animDuration).clamp(0.0, 1.0);
      final t = Curves.easeInOutCubic.transform(_animProgress);
      _camera.lerpFrom(_fromCamera!, _toCamera!, t);
    }

    // WASD 平移（沿屏幕方向）
    if (_pressed.isEmpty) return;
    final speed = _baseMoveSpeed / _camera.zoom * dt;

    double sx = 0, sy = 0;
    if (_pressed.contains(LogicalKeyboardKey.keyA) ||
        _pressed.contains(LogicalKeyboardKey.arrowLeft)) {
      sx -= 1;
    }
    if (_pressed.contains(LogicalKeyboardKey.keyD) ||
        _pressed.contains(LogicalKeyboardKey.arrowRight)) {
      sx += 1;
    }
    if (_pressed.contains(LogicalKeyboardKey.keyW) ||
        _pressed.contains(LogicalKeyboardKey.arrowUp)) {
      sy -= 1;
    }
    if (_pressed.contains(LogicalKeyboardKey.keyS) ||
        _pressed.contains(LogicalKeyboardKey.arrowDown)) {
      sy += 1;
    }
    if (sx == 0 && sy == 0) return;

    final worldDir = _camera.screenToWorldDirection(sx, sy);
    _camera.target = Vector2(
      _camera.targetX + worldDir.x * speed,
      _camera.targetY + worldDir.y * speed,
    );
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final delta = info.scrollDelta.global.y;
    if (delta == 0) return;

    final multiplier = delta < 0 ? _zoomFactor : 1 / _zoomFactor;
    _camera.zoom = (_camera.zoom * multiplier).clamp(0.1, _maxZoom);
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _pressed
      ..clear()
      ..addAll(keysPressed);

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      _isTopDown = !_isTopDown;
      _fromCamera = _camera.snapshot();
      _toCamera = _isTopDown
          ? Camera3D.topDown(target: _camera.target.clone(), zoom: 5)
          : Camera3D.isometric(target: _camera.target.clone(), zoom: 5);
      _animProgress = 0.0;
      return false;
    }
    return true;
  }
}
