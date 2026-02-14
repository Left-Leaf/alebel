import '../unit/unit_state.dart';

abstract class Buff {
  String get id;
  String get name;
  String get description;
  
  /// 优先级，数值越小越先计算
  int get priority => 0;

  int duration; // 剩余回合数

  Buff({required this.duration});

  /// 应用 Buff 效果到 UnitState
  /// 在每次属性重算时调用
  void apply(UnitState state);

  /// 回合开始时调用
  void onTurnStart(UnitState state) {}

  /// 回合结束时调用
  /// 返回 true 表示 Buff 已过期应该移除
  bool onTurnEnd(UnitState state) {
    duration--;
    return duration <= 0;
  }
}
