import 'package:flame/components.dart';
import 'package:flame/events.dart';

import 'scene.dart';

/// 模式基类。
///
/// 负责：
/// - 规则的制定与游戏逻辑
/// - 交互的处理
abstract class Mode<T extends Scene> extends Component with ParentIsA<T> {
  /// 模式名称标识
  String get modeName;

  /// 模式激活时调用
  Future<void> onActivate() async {}

  /// 模式停用时调用
  Future<void> onDeactivate() async {}

  /// 接收滚轮事件，子类可覆写以实现缩放等交互。
  void onScroll(PointerScrollInfo info) {}
}
