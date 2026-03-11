import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show KeyEvent, KeyEventResult;
import 'package:flutter/services.dart' show LogicalKeyboardKey, KeyDownEvent;

import 'framework/scene.dart';

/// 场景切换观察者
class SceneObserver {
  final void Function(String sceneName)? onSwitch;
  SceneObserver({this.onSwitch});
}

/// Alpha 框架游戏入口
class AlphaGame extends FlameGame with ScrollDetector, KeyboardEvents {
  Scene? _currentScene;
  final Map<String, Scene Function()> _sceneFactories = {};
  final List<String> _sceneOrder = [];
  final List<SceneObserver> _observers = [];

  Scene? get currentScene => _currentScene;

  void addObserver(SceneObserver observer) => _observers.add(observer);

  void removeObserver(SceneObserver observer) => _observers.remove(observer);

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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

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
      remove(_currentScene!);
    }

    final newScene = factory();
    _currentScene = newScene;
    add(newScene);
    await newScene.loaded;

    for (final observer in _observers) {
      observer.onSwitch?.call(sceneName);
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      final idx = _digitKeys.indexOf(event.logicalKey);
      if (idx >= 0 && idx < _sceneOrder.length) {
        final target = _sceneOrder[idx];
        if (_currentScene?.name != target) {
          switchTo(target);
        }
        return KeyEventResult.handled;
      }
    }
    final mode = currentScene?.mode;
    if (mode != null) {
      return mode.onKeyEvent(event, keysPressed) ? KeyEventResult.ignored : KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final mode = currentScene?.mode;
    if (mode != null) {
      mode.onScroll(info);
    }
  }
}
