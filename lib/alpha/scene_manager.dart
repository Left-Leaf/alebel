import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';

import 'framework/scene.dart';

/// 场景管理器 — 管理游戏级别的场景切换
///
/// 混入 [KeyboardHandler]，通过数字键 1-9 在已注册场景间切换。
class SceneManager extends Component with KeyboardHandler {
  Scene? _currentScene;
  final Map<String, Scene Function()> _sceneFactories = {};
  final List<String> _sceneOrder = [];

  Scene? get currentScene => _currentScene;

  void registerScene(String name, Scene Function() factory) {
    _sceneFactories[name] = factory;
    if (!_sceneOrder.contains(name)) {
      _sceneOrder.add(name);
    }
  }

  Future<void> switchTo(String sceneName) async {
    final factory = _sceneFactories[sceneName];
    if (factory == null) {
      throw Exception('Scene not found: $sceneName');
    }

    if (_currentScene != null) {
      await _currentScene!.onExit();
      remove(_currentScene!);
    }

    final newScene = factory();
    _currentScene = newScene;
    add(newScene);
    await newScene.loaded;
    await newScene.onEnter();
  }

  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  void onScroll(PointerScrollInfo info) {
    _currentScene?.onScroll(info);
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      final idx = _digitKeys.indexOf(event.logicalKey);
      if (idx >= 0 && idx < _sceneOrder.length) {
        final target = _sceneOrder[idx];
        if (_currentScene?.name != target) {
          switchTo(target);
        }
        return false;
      }
    }
    return true;
  }
}
