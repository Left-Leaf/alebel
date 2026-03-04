import '../battle/battle_api.dart';
import '../map/board.dart';
import '../map/game_map.dart';
import '../unit/unit_state.dart';

/// AI 决策上下文（仅包含核心层数据）
class AIContext {
  final GameMap gameMap;
  final List<UnitState> units;
  final UnitState? Function(int x, int y) getUnitAt;

  const AIContext({
    required this.gameMap,
    required this.units,
    required this.getUnitAt,
  });
}

/// AI 行动结果（abstract class，子类自带 execute 实现）
abstract class AIAction {
  const AIAction();

  Future<void> execute(UnitState unit, BattleAPI api);
}

/// 沿路径移动
class AIMove extends AIAction {
  final List<Position> path;
  const AIMove(this.path);

  @override
  Future<void> execute(UnitState unit, BattleAPI api) async {
    await api.moveUnit(unit, path);
  }
}

/// 攻击目标单位
class AIAttack extends AIAction {
  final UnitState target;
  final int attackPower;
  const AIAttack({required this.target, required this.attackPower});

  @override
  Future<void> execute(UnitState unit, BattleAPI api) async {
    await api.damageUnit(target, attackPower, attacker: unit);
  }
}
