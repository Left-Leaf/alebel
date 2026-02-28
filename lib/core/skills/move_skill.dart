part of 'skill.dart';

class MoveSkill extends Skill {
  @override
  String get name => 'Move';

  List<List<Position>> _currentPaths = [];
  Position? _lastCalcPos;
  int? _lastPoints;

  // Helper to ensure paths are up to date
  void _ensurePaths(UnitState state, AlebelGame game) {
    final startPos = (x: state.x, y: state.y);
    final points = state.currentActionPoints;
    // Only recalc if needed
    if (_lastCalcPos?.x != state.x ||
        _lastCalcPos?.y != state.y ||
        _lastPoints != points ||
        _currentPaths.isEmpty) {
      // Use currentActionPoints as the move power limit
      _currentPaths = game.gameMap.getMovablePositions(startPos, points);
      _lastCalcPos = startPos;
      _lastPoints = points;
    }
  }

  @override
  List<({int x, int y, Color color})> getHighlightPositions(UnitState state, AlebelGame game) {
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
      final attackablePositions = _getAttackablePositions(target, attackRange, game);

      for (final pos in attackablePositions) {
        // Since RangeLayer uses a Map internally, last added color wins.
        // We add red after blue, so attack range overlays move range.
        highlights.add((x: pos.x, y: pos.y, color: Colors.red.withOpacity(0.3)));
      }
    }

    return highlights;
  }

  @override
  bool onCellTap(UnitState state, CellComponent cell, AlebelGame game) {
    if (game.turnManager.activeUnit != state) {
      // 不是该单位的回合，放弃焦点，切到点击的格子
      game.focusCell = cell;
      return false;
    }

    _ensurePaths(state, game);
    final targetPos = (x: cell.gridX, y: cell.gridY);

    if (!_isReachable(targetPos)) {
      // 不可达 → 放弃当前单位，焦点切到点击的格子
      game.focusCell = cell;
      return false;
    }

    // 检查目标位置是否被可见单位阻挡
    final targetUnit = game.unitLayer.getUnitAt(targetPos.x, targetPos.y);
    if (targetUnit != null) {
      if (targetUnit.state != state) {
        final cellState = game.gameMap.getCell(targetPos.x, targetPos.y);
        if (cellState.isCenterVisible) {
          // 被可见单位阻挡 → 焦点切到该格子
          game.focusCell = cell;
          return false;
        }
      } else {
        game.focusCell = null;
        return false;
      }
    }

    // 可达且未阻挡
    if (state.previewPosition?.x == targetPos.x && state.previewPosition?.y == targetPos.y) {
      _confirmMovement(state, game);
      return true;
    } else {
      state.previewPosition = targetPos;
      game.updateRangeLayer();
      game.updatePreviewUnit();
      return false;
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

      game.focusCell = null;

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
          print("Movement blocked by terrain at ${endPoint.x}, ${endPoint.y}");
        }

        // Check Unit
        if (!blocked) {
          final isCenterVisible = game.gameMap.getCell(endPoint.x, endPoint.y).isCenterVisible;
          if (!isCenterVisible) {
            blocked = false;
            print("Movement blocked by center visibility at ${endPoint.x}, ${endPoint.y}");
          } else {
            final otherUnit = game.unitLayer.getUnitAt(endPoint.x, endPoint.y);
            if (otherUnit != null && otherUnit != unitComponent) {
              blocked = true;
              print("Movement blocked by unit at ${endPoint.x}, ${endPoint.y}");
            }
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
        print("Stopped at invalid position $currentPos, backtracking to $lastValidPos");

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

        for (int k = 0; k < path.length; k++) {
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
            },
          ),
        );
        await completer.future;
      }

      // 重置技能并重新聚焦到移动后的位置
      state.focusSkill = state.unit.moveSkill;
      game.focusCell = game.gridLayer.getCell(state.x, state.y);
    }
  }

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
