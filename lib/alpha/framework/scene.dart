import 'package:flame/components.dart';
import 'package:flutter/cupertino.dart';

import 'camera/camera_3d_component.dart';
import 'world.dart';
import 'mode.dart';
import 'state.dart';

/// 场景 — Alpha 框架的最顶层单元。
///
/// 一个场景内包含四个核心部分：
/// - [camera]：3D 相机，控制视角；世界内容添加到 viewfinder，HUD 添加到 viewport
/// - [SceneState]：存储场景状态，为逻辑和渲染提供数据支持
/// - [SceneWorld]：地图加载、Component 渲染
/// - [Mode]：规则制定、交互处理
///
/// Scene 持有 [Camera3DComponent]，所有需要相机的子组件通过 Scene 访问。
abstract class Scene extends Component {
  String get name;

  /// 3D 相机组件。
  final Camera3DComponent camera = Camera3DComponent();

  SceneState get state;

  SceneWorld get world;

  Mode? _mode;

  Mode? get mode => _mode;

  @mustCallSuper
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(camera);
    await add(state);
    await camera.viewfinder.add(world);
  }

  /// 按名称切换模式
  Future<void> switchModeTo(Mode mode) async {
    if (_mode == mode) return;
    _mode?.removeFromParent();
    _mode = null;
    await mode.addToParent(this);
    _mode = mode;
  }
}
