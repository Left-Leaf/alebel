part of 'skill.dart';

class AttackSkill extends Skill {
  @override
  String get name => 'Attack';

  @override
  int get maxUsesPerTurn => 1;

  @override
  List<({Position pos, Color color})> getHighlightPositions(
    UnitState state,
    SkillContext ctx,
  ) {
    final positions = Skill.getPositionsInRange(
      (x: state.x, y: state.y),
      state.unit.attackRange,
      mapWidth: ctx.gameMap.width,
      mapHeight: ctx.gameMap.height,
    );
    return positions.map((pos) => (pos: pos, color: AlebelTheme.highlightAttack)).toList();
  }

  @override
  Future<bool> onTap(UnitState state, Position target, BattleAPI api) async {
    if (api.activeUnit != state) return false;

    final targetUnit = api.getUnitAt(target.x, target.y);
    if (targetUnit == null || !state.unit.faction.isHostileTo(targetUnit.unit.faction)) {
      return false;
    }

    final cellState = api.gameMap.getCell(target.x, target.y);
    if (!cellState.isCenterVisible) return false;

    final distance = (target.x - state.x).abs() + (target.y - state.y).abs();
    if (distance > state.unit.attackRange) return false;

    await api.damageUnit(targetUnit, state.currentAttack, attacker: state);
    api.switchSkill(state, state.unit.moveSkill);
    return true;
  }
}
