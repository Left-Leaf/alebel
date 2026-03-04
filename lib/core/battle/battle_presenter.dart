import '../buffs/buff.dart';
import '../unit/unit_state.dart';

/// 战斗表现层接口
///
/// [BattleController] 通过此接口驱动视觉效果。
/// 定义在 core 层，由 presentation 层实现。
abstract class BattlePresenter {
  Future<void> showDamage(UnitState unit, int damage);
  Future<void> showHeal(UnitState unit, int amount);
  Future<void> showDeath(UnitState unit);
  Future<void> showBuffApplied(UnitState unit, Buff buff);
  Future<void> showBuffRemoved(UnitState unit, Buff buff);
  Future<void> showBattleEnd(bool playerWon);
}
