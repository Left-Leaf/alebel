import '../battle/battle_api.dart';
import '../unit/unit_state.dart';

export 'poison_buff.dart';
export 'attack_boost_buff.dart';
export 'speed_debuff_buff.dart';

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
  Future<void> onTurnStart(UnitState state, {BattleAPI? api}) async {}

  /// 回合结束时调用
  /// 返回 true 表示 Buff 已过期应该移除
  Future<bool> onTurnEnd(UnitState state, {BattleAPI? api}) async {
    duration--;
    return duration <= 0;
  }

  /// 受到伤害时调用，返回修正后的伤害值
  /// 可用于实现护盾、减伤等效果
  Future<int> onDamageTaken(UnitState state, int damage,
      {UnitState? attacker, BattleAPI? api}) async =>
      damage;

  /// 造成伤害后调用
  /// 可用于实现吸血、连锁伤害等效果
  Future<void> onDamageDealt(UnitState state, UnitState target, int damage,
      {BattleAPI? api}) async {}
}
