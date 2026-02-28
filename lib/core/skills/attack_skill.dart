part of 'skill.dart';

class AttackSkill extends Skill {
  @override
  String get name => 'Attack';

  @override
  List<({int x, int y, Color color})> getHighlightPositions(UnitState state, BoardComponent board) {
    final startPos = (x: state.x, y: state.y);
    final attackRange = state.unit.attackRange;
    final attackablePositions = _getAttackablePositions(startPos, attackRange, board);

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
        // TODO: Implement damage logic

        // Attack performed, end turn
        // board.turnManager.endTurn();

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

  // Helper from MoveSkill (duplicated for now as it's not exposed elsewhere cleanly)
  List<Position> _getAttackablePositions(Position center, int range, BoardComponent board) {
    final positions = <Position>[];
    for (var dx = -range; dx <= range; dx++) {
      for (var dy = -range; dy <= range; dy++) {
        if (dx.abs() + dy.abs() <= range) {
          final x = center.x + dx;
          final y = center.y + dy;
          if (x >= 0 && x < board.gameMap.width && y >= 0 && y < board.gameMap.height) {
            if (dx == 0 && dy == 0) continue;
            positions.add((x: x, y: y));
          }
        }
      }
    }
    return positions;
  }
}
