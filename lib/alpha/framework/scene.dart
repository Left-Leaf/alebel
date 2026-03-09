import 'package:flame/components.dart';
import 'package:flame/events.dart';

import 'mode.dart';
import 'scene_map.dart';
import 'scene_state.dart';

/// 场景 — Alpha 框架的最顶层单元。
///
/// 一个场景内包含三个核心组件：
/// - [SceneState]：存储场景状态，为逻辑和渲染提供数据支持
/// - [SceneMap]：地图加载、相机控制、Component 渲染
/// - [Mode]：规则制定、交互处理
///
/// 三者在 Scene 构建时一并创建，之后不再增删。
/// SceneState、SceneMap、Mode 均为 Scene 的直接子组件，通过 [ParentIsA] 访问所属 Scene。
abstract class Scene extends Component {
  String get name;

  final SceneState state;
  final SceneMap sceneMap;
  final Map<String, Mode> modes;

  Mode? _currentMode;

  Scene({required this.state, required this.sceneMap, required this.modes});

  Mode? get currentMode => _currentMode;
  String? get currentModeName => _currentMode?.modeName;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(state);
    add(sceneMap);
    modes.values.forEach(add);
  }

  /// 按名称切换模式
  Future<void> switchModeTo(String modeName) async {
    final mode = modes[modeName];
    if (mode == null) {
      throw Exception('Mode not found: $modeName');
    }
    if (_currentMode == mode) return;

    if (_currentMode != null) {
      await _currentMode!.onDeactivate();
    }
    _currentMode = mode;
    await mode.onActivate();
  }

  /// 场景进入时调用
  Future<void> onEnter() async {}

  /// 场景退出时调用
  Future<void> onExit() async {
    if (_currentMode != null) {
      await _currentMode!.onDeactivate();
    }
  }

  /// 转发滚轮事件到当前激活的模式。
  void onScroll(PointerScrollInfo info) {
    _currentMode?.onScroll(info);
  }
}
