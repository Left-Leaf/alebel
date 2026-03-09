import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'demo/camera_demo/camera_demo_scene.dart';
import 'demo/world_demo/world_demo_scene.dart';
import 'scene_manager.dart';

/// Alpha 框架游戏入口
class AlphaGame extends FlameGame
    with ScrollDetector, HasKeyboardHandlerComponents {
  late final SceneManager sceneManager;

  @override
  Color backgroundColor() => const Color(0xFF222222);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sceneManager = SceneManager();
    world.add(sceneManager);

    sceneManager.registerScene('camera_demo', CameraDemoScene.new);
    sceneManager.registerScene('world_demo', WorldDemoScene.new);
    await sceneManager.switchTo('camera_demo');
  }

  @override
  void onScroll(PointerScrollInfo info) {
    sceneManager.onScroll(info);
  }
}
