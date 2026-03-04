import '../skills/skill.dart';
import '../map/board.dart';
import '../unit/unit_state.dart';
import 'ai_action.dart';

/// AI 策略接口
///
/// 每个单位可配置不同的 AI 策略。
/// 实现者只需覆写 [decideTurn]，返回行动列表。
abstract class AIStrategy {
  const AIStrategy();

  /// 决定本回合的所有行动（纯逻辑，不执行任何副作用）
  List<AIAction> decideTurn(UnitState unit, AIContext ctx);
}

/// 默认贪心 AI：寻找最近敌人，接近并攻击
class AggressiveAI extends AIStrategy {
  const AggressiveAI();

  @override
  List<AIAction> decideTurn(UnitState unit, AIContext ctx) {
    final actions = <AIAction>[];

    // 1. 找最近的敌对单位（曼哈顿距离）
    final target = _findNearestEnemy(unit, ctx);
    if (target == null) return actions;

    // 找到攻击技能
    final attackSkill = unit.unit.skills.whereType<AttackSkill>().firstOrNull;

    // 2. 若已在攻击范围 → 攻击
    if (_isInAttackRange(unit, target) && attackSkill != null) {
      actions.add(AIUseSkill(skill: attackSkill, target: (x: target.x, y: target.y)));
      return actions;
    }

    // 3. 寻路到目标最近的可达位置
    final paths = ctx.gameMap.getMovablePositions(
      (x: unit.x, y: unit.y),
      unit.currentActionPoints,
    );

    List<Position>? bestPath;
    int bestDistance = _manhattan(unit.x, unit.y, target.x, target.y);

    for (final (path, _) in paths) {
      if (path.length <= 1) continue;
      final end = path.last;

      final occupant = ctx.getUnitAt(end.x, end.y);
      if (occupant != null && occupant != unit) continue;

      final dist = _manhattan(end.x, end.y, target.x, target.y);
      if (dist < bestDistance) {
        bestDistance = dist;
        bestPath = path;
      }
    }

    // 4. 移动
    if (bestPath != null) {
      actions.add(AIMove(bestPath));
    }

    // 5. 移动后再次检查攻击范围
    if (attackSkill != null) {
      final endPos = bestPath != null ? bestPath.last : (x: unit.x, y: unit.y);
      final distAfterMove = _manhattan(endPos.x, endPos.y, target.x, target.y);
      if (distAfterMove <= unit.unit.attackRange) {
        actions.add(AIUseSkill(skill: attackSkill, target: (x: target.x, y: target.y)));
      }
    }

    return actions;
  }

  UnitState? _findNearestEnemy(UnitState unit, AIContext ctx) {
    UnitState? nearest;
    int minDist = 999999;

    for (final u in ctx.units) {
      if (unit.unit.faction.isHostileTo(u.unit.faction)) {
        final dist = _manhattan(unit.x, unit.y, u.x, u.y);
        if (dist < minDist) {
          minDist = dist;
          nearest = u;
        }
      }
    }

    return nearest;
  }

  bool _isInAttackRange(UnitState attacker, UnitState target) {
    final dist = _manhattan(attacker.x, attacker.y, target.x, target.y);
    return dist <= attacker.unit.attackRange;
  }

  int _manhattan(int x1, int y1, int x2, int y2) {
    return (x1 - x2).abs() + (y1 - y2).abs();
  }
}
