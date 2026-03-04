import '../unit/unit_state.dart';

/// 回合生命周期接口
///
/// [TurnManager] 通过此接口通知回合事件，由 [BattleController] 实现。
abstract class TurnDelegate {
  Future<void> onTurnStart(UnitState unit);
  Future<void> onTurnEnd(UnitState unit);
  Future<void> onBuffTurnStart(UnitState unit);
  Future<void> onBuffTurnEnd(UnitState unit);
  Future<void> onCellTurnStart(UnitState unit);
  Future<void> onUnitDeath(UnitState unit);
}
