import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../presentation/components/cell_component.dart';
import '../../game/alebel_game.dart';
import '../map/board.dart';
import '../unit/unit_state.dart';
import 'skill.dart';

class MoveSkill extends Skill {
  @override
  String get name => 'Move';

  List<List<Position>> _currentPaths = [];
  Position? _lastCalcPos;

  // Helper to ensure paths are up to date
  void _ensurePaths(UnitState state, AlebelGame game) {
    // Only recalc if needed
    if (_lastCalcPos?.x != state.x ||
        _lastCalcPos?.y != state.y ||
        _currentPaths.isEmpty) {
      final startPos = (x: state.x, y: state.y);
      // Use currentActionPoints as the move power limit
      _currentPaths = game.gameMap.getMovablePositions(
        startPos,
        state.currentActionPoints,
      );
      _lastCalcPos = startPos;
    }
  }

  @override
  List<({int x, int y, Color color})> getHighlightPositions(
    UnitState state,
    AlebelGame game,
  ) {
    final highlights = <({int x, int y, Color color})>[];

    // 1. Always calculate and show move range (Blue)
    _ensurePaths(state, game);
    final reachableSet = <Position>{};
    for (final path in _currentPaths) {
      reachableSet.addAll(path);
    }
    reachableSet.remove((x: state.x, y: state.y)); // Remove start

    // Add move range highlights
    for (final pos in reachableSet) {
      highlights.add((x: pos.x, y: pos.y, color: Colors.blue.withOpacity(0.3)));
    }

    // 2. If preview active, calculate and show attack range (Red)
    if (state.previewPosition != null) {
      final target = state.previewPosition!;
      final attackRange = state.unit.attackRange;
      final attackablePositions = _getAttackablePositions(
        target,
        attackRange,
        game,
      );

      for (final pos in attackablePositions) {
        // Since RangeLayer uses a Map internally, last added color wins.
        // We add red after blue, so attack range overlays move range.
        highlights.add((
          x: pos.x,
          y: pos.y,
          color: Colors.red.withOpacity(0.3),
        ));
      }
    }

    return highlights;
  }

  @override
  void onCellTap(UnitState state, CellComponent cell, AlebelGame game) {
    // Only allow interaction if it's this unit's turn
    if (game.turnManager.activeUnit != state) {
      print("Not this unit's turn!");
      return;
    }

    _ensurePaths(state, game);
    final targetPos = (x: cell.gridX, y: cell.gridY);

    if (_isReachable(targetPos)) {
      // Check if there is another unit at the target position (that is visible)
      final targetUnit = game.unitLayer.getUnitAt(targetPos.x, targetPos.y);
      bool isBlockedByUnit = false;

      if (targetUnit != null && targetUnit != game.selectedUnit) {
        // If unit is in fog (unknown), we treat it as empty (move allowed until revealed)
        // But if unit is visible, we cannot stand on it.
        // Note: unitLayer.getUnitAt returns unit if exists.
        // We need to check visibility.
        final cellState = game.gameMap.getCell(targetPos.x, targetPos.y);
        // If cell is visible (center visible), then we know there is a unit, so we cannot move there.
        if (cellState.isCenterVisible) {
          isBlockedByUnit = true;
        }
      }

      if (!isBlockedByUnit) {
        if (state.previewPosition?.x == targetPos.x &&
            state.previewPosition?.y == targetPos.y) {
          _confirmMovement(state, game);
        } else {
          // Show projection
          state.previewPosition = targetPos;
          game.updateRangeLayer();
        }
      } else {
        // Blocked by visible unit -> cannot move here
        print("Cannot move to ${targetPos.x}, ${targetPos.y}: Blocked by unit");
        // Maybe select that unit or cell instead?
        // For now, treat as invalid move click
        game.deselectUnit();
        game.selectCell(cell);
      }
    } else {
      // Not reachable
      game.deselectUnit();
      game.selectCell(cell);
    }
  }

  bool _isReachable(Position pos) {
    for (final path in _currentPaths) {
      if (path.isNotEmpty) {
        final end = path.last;
        if (end.x == pos.x && end.y == pos.y) return true;
      }
    }
    return false;
  }

  Future<void> _confirmMovement(UnitState state, AlebelGame game) async {
    final target = state.previewPosition;
    if (target == null) return;

    // Find path
    List<Position>? path;
    for (final p in _currentPaths) {
      if (p.isNotEmpty && p.last.x == target.x && p.last.y == target.y) {
        path = p;
        break;
      }
    }

    if (path != null) {
      final unitComponent = game.unitLayer.getUnitAt(state.x, state.y);
      if (unitComponent == null) return;

      game.deselectUnit(); // This will clear previewPosition via game logic

      // Move step by step
      // path[0] is current position (or start position), we start moving to path[1]
      // Cost calculation: each step costs 1 AP

      Position lastValidPos = path[0];

      for (int i = 1; i < path.length; i++) {
        // Check if we have enough AP
        if (state.currentActionPoints <= 0) break;

        final nextPoint = path[i];

        // 1. Check if endpoint is reachable (Terrain & Unit)
        // Note: gameMap.blocksPass now returns true for obstacles if they are visible/explored.
        // updateFog() is called after each step, so if we just revealed an obstacle, blocksPass will be true.
        bool blocked = false;
        final endPoint = path.last;

        // Check Terrain
        if (game.gameMap.blocksPass(endPoint.x, endPoint.y)) {
          blocked = true;
          print(
            "Movement blocked by terrain at ${endPoint.x}, ${endPoint.y}",
          );
        }

        // Check Unit
        if (!blocked) {
          final otherUnit = game.unitLayer.getUnitAt(endPoint.x, endPoint.y);
          if (otherUnit != null && otherUnit != unitComponent) {
            blocked = true;
            print("Movement blocked by unit at ${endPoint.x}, ${endPoint.y}");
          }
        }

        if (blocked) {
          // Stop movement
          break;
        }

        // 2. Perform Move
        final targetPos = Vector2(
          (nextPoint.x + 0.5) * CellComponent.cellSize,
          (nextPoint.y + 0.5) * CellComponent.cellSize,
        );

        final completer = Completer<void>();
        game.add(
          MoveToEffect(
            targetPos,
            EffectController(speed: 200),
            target: unitComponent,
            onComplete: () {
              // Update Logic Position
              state.x = nextPoint.x;
              state.y = nextPoint.y;
              // Deduct AP
              state.currentActionPoints--;

              // Reveal Fog
              game.updateFog();
              completer.complete();
            },
          ),
        );

        await completer.future;

        // Check if current position is valid for stopping
        // If there is no unit at current position (except self), update lastValidPos
        final unitAtCurrent = game.unitLayer.getUnitAt(state.x, state.y);
        if (unitAtCurrent == null || unitAtCurrent == unitComponent) {
          lastValidPos = nextPoint;
        }
      }

      // 3. Final Check: If stopped at an invalid position (e.g. on top of another unit), backtrack
      final currentPos = (x: state.x, y: state.y);
      if (currentPos.x != lastValidPos.x || currentPos.y != lastValidPos.y) {
        print("Stopped at invalid position ${currentPos}, backtracking to $lastValidPos");
        
        // Calculate AP refund (if any)
        // If we moved 3 steps but had to backtrack to step 1, we should probably only cost 1 AP?
        // Or keep the cost as penalty? For better UX, let's just sync AP to the final position distance.
        // But path finding might be complex. Simplest is to just refund the diff.
        // state.currentActionPoints += (steps moved beyond lastValidPos)
        
        // Find how many steps we moved in total vs how many to lastValidPos
        // path contains [start, p1, p2, ... end]
        // We moved along path.
        
        int currentIndexInPath = -1;
        int validIndexInPath = -1;
        
        for(int k=0; k<path.length; k++) {
           if (path[k].x == currentPos.x && path[k].y == currentPos.y) currentIndexInPath = k;
           if (path[k].x == lastValidPos.x && path[k].y == lastValidPos.y) validIndexInPath = k;
        }
        
        if (currentIndexInPath != -1 && validIndexInPath != -1) {
           final stepsToRefund = currentIndexInPath - validIndexInPath;
           if (stepsToRefund > 0) {
              state.currentActionPoints += stepsToRefund;
           }
        }

        // Backtrack Move
        state.x = lastValidPos.x;
        state.y = lastValidPos.y;
        
        final targetPos = Vector2(
          (lastValidPos.x + 0.5) * CellComponent.cellSize,
          (lastValidPos.y + 0.5) * CellComponent.cellSize,
        );
        
        final completer = Completer<void>();
        game.add(
           MoveToEffect(
            targetPos,
            EffectController(speed: 300),
            target: unitComponent,
            onComplete: () {
               game.updateFog(); // Update fog again at final pos
               completer.complete();
            }
           )
        );
        await completer.future;
      }

      // Select unit at new position
      // Don't select again if turn ends immediately after move (optional design choice)
      // game.selectUnit(unitComponent);

      // End Turn after move (Simple logic for now)
      // game.turnManager.endTurn();

      // Switch back to MoveSkill or stay
      state.currentSkill = state.unit.moveSkill;
      game.updateRangeLayer();
    }
  }

  List<Position> _getAttackablePositions(
    Position center,
    int range,
    AlebelGame game,
  ) {
    final positions = <Position>[];
    for (var dx = -range; dx <= range; dx++) {
      for (var dy = -range; dy <= range; dy++) {
        if (dx.abs() + dy.abs() <= range) {
          final x = center.x + dx;
          final y = center.y + dy;
          if (x >= 0 &&
              x < game.gameMap.width &&
              y >= 0 &&
              y < game.gameMap.height) {
            if (dx == 0 && dy == 0) continue;
            positions.add((x: x, y: y));
          }
        }
      }
    }
    return positions;
  }
}
