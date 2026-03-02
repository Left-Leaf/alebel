part of 'skill.dart';

class AttackSkill extends Skill {
  @override
  String get name => 'Attack';

  @override
  List<({int x, int y, Color color})> getHighlightPositions(UnitState state, BoardComponent board) {
    final startPos = (x: state.x, y: state.y);
    final attackRange = state.unit.attackRange;
    final attackablePositions = Skill.getPositionsInRange(
      startPos, attackRange,
      mapWidth: board.gameMap.width, mapHeight: board.gameMap.height,
    );

    return attackablePositions.map((pos) => (
      x: pos.x,
      y: pos.y,
      color: Colors.red.withOpacity(0.3)
    )).toList();
  }

  @override
  bool onCellTap(UnitState state, CellComponent cell, BoardComponent board) {
    // Only allow interaction if it's this unit's turn
    if (board.turnManager.activeUnit != state) return false;

    // Handle attack logic
    final target = board.unitLayer.getUnitAt(cell.gridX, cell.gridY);

    // Check if target is valid and visible
    bool isValidTarget = false;
    if (target != null && target.faction != state.unit.faction) {
       final cellState = board.gameMap.getCell(cell.gridX, cell.gridY);
       if (cellState.isCenterVisible) {
         isValidTarget = true;
       }
    }

    if (isValidTarget) {
      // Check range
      final distance = (cell.gridX - state.x).abs() + (cell.gridY - state.y).abs();
      if (distance <= state.unit.attackRange) {
        print('Attacking unit at ${cell.gridX}, ${cell.gridY}');

        // 造成伤害
        final targetState = target!.state;
        final damage = targetState.takeDamage(state.currentAttack);
        board.eventBus.fire(UnitDamagedEvent(unit: targetState, damage: damage));

        // 检查死亡
        if (targetState.isDead) {
          board.handleUnitDeath(targetState);
        }

        // Switch back to MoveSkill
        _switchToMove(state, board);
        return true;
      } else {
        print('Target out of range');
        // Stay in attack mode
        return false;
      }
    } else {
      // Clicked empty space or ally -> Stay in attack mode
      return false;
    }
  }

  void _switchToMove(UnitState state, BoardComponent board) {
    state.focusSkill = state.unit.moveSkill;
    board.updateRangeLayer();
  }
}
