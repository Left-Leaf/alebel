
import 'package:flutter/material.dart';

import '../../presentation/components/cell_component.dart';
import '../../game/alebel_game.dart';
// import '../../models/units/unit_base.dart';
import '../map/board.dart';
import '../unit/unit_state.dart';
import 'skill.dart';

class AttackSkill extends Skill {
  @override
  String get name => 'Attack';

  @override
  List<({int x, int y, Color color})> getHighlightPositions(UnitState state, AlebelGame game) {
    final startPos = (x: state.x, y: state.y);
    final attackRange = state.unit.attackRange;
    final attackablePositions = _getAttackablePositions(startPos, attackRange, game);
    
    return attackablePositions.map((pos) => (
      x: pos.x, 
      y: pos.y, 
      color: Colors.red.withOpacity(0.3)
    )).toList();
  }

  @override
  void onCellTap(UnitState state, CellComponent cell, AlebelGame game) {
    // Only allow interaction if it's this unit's turn
    if (game.turnManager.activeUnit != state) return;

    // Handle attack logic
    final target = game.unitLayer.getUnitAt(cell.gridX, cell.gridY);
    
    // Check if target is valid and visible
    bool isValidTarget = false;
    if (target != null && target.faction != state.unit.faction) {
       final cellState = game.gameMap.getCell(cell.gridX, cell.gridY);
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
        // game.turnManager.endTurn();
        
        // Switch back to MoveSkill
        _switchToMove(state, game);
      } else {
        print('Target out of range');
        // Stay in attack mode
      }
    } else {
      // Clicked empty space or ally -> Stay in attack mode
    }
  }

  void _switchToMove(UnitState state, AlebelGame game) {
    // Just switch state, game updates will handle layer/rendering changes
    state.currentSkill = state.unit.moveSkill;
    game.updateRangeLayer();
    
    // If we wanted to re-trigger "selected" logic of move skill, we'd do it here.
    // But since MoveSkill just calculates ranges lazily/on-demand, we just need to ensure UI updates.
  }

  // Helper from MoveSkill (duplicated for now as it's not exposed elsewhere cleanly)
  List<Position> _getAttackablePositions(Position center, int range, AlebelGame game) {
    final positions = <Position>[];
    for (var dx = -range; dx <= range; dx++) {
      for (var dy = -range; dy <= range; dy++) {
        if (dx.abs() + dy.abs() <= range) {
          final x = center.x + dx;
          final y = center.y + dy;
          if (x >= 0 && x < game.gameMap.width && y >= 0 && y < game.gameMap.height) {
            if (dx == 0 && dy == 0) continue;
            positions.add((x: x, y: y));
          }
        }
      }
    }
    return positions;
  }
}
