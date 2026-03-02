part of 'skill.dart';

class MoveSkill extends Skill {
  @override
  String get name => 'Move';

  List<(List<Position>, PathCertainty)> _currentPaths = [];
  Position? _lastCalcPos;
  int? _lastPoints;

  // Helper to ensure paths are up to date
  void _ensurePaths(UnitState state, BoardComponent board) {
    final startPos = (x: state.x, y: state.y);
    final points = state.currentActionPoints;
    // Only recalc if needed
    if (_lastCalcPos?.x != state.x ||
        _lastCalcPos?.y != state.y ||
        _lastPoints != points ||
        _currentPaths.isEmpty) {
      // Use currentActionPoints as the move power limit
      _currentPaths = board.gameMap.getMovablePositions(startPos, points);
      _lastCalcPos = startPos;
      _lastPoints = points;
    }
  }

  @override
  List<({int x, int y, Color color})> getHighlightPositions(UnitState state, BoardComponent board) {
    final highlights = <({int x, int y, Color color})>[];

    // 1. Always calculate and show move range (Blue)
    _ensurePaths(state, board);

    // 收集所有可达格子及其最佳确定性
    final cellCertainty = <Position, PathCertainty>{};
    for (final (path, certainty) in _currentPaths) {
      for (final pos in path) {
        final existing = cellCertainty[pos];
        // confirmed 优先于 uncertain
        if (existing == null || certainty == PathCertainty.confirmed) {
          cellCertainty[pos] = certainty;
        }
      }
    }
    cellCertainty.remove((x: state.x, y: state.y));

    for (final entry in cellCertainty.entries) {
      final opacity = entry.value == PathCertainty.confirmed ? 0.3 : 0.15;
      highlights.add((x: entry.key.x, y: entry.key.y, color: Colors.blue.withOpacity(opacity)));
    }

    // 2. If preview active, calculate and show attack range (Red)
    if (state.previewPosition != null) {
      final target = state.previewPosition!;
      final attackRange = state.unit.attackRange;
      final attackablePositions = Skill.getPositionsInRange(
        target, attackRange,
        mapWidth: board.gameMap.width, mapHeight: board.gameMap.height,
      );

      for (final pos in attackablePositions) {
        highlights.add((x: pos.x, y: pos.y, color: Colors.red.withOpacity(0.3)));
      }
    }

    return highlights;
  }

  @override
  bool onCellTap(UnitState state, CellComponent cell, BoardComponent board) {
    if (board.turnManager.activeUnit != state) {
      // 不是该单位的回合，放弃焦点，切到点击的格子
      board.focusCell = cell;
      return false;
    }

    _ensurePaths(state, board);
    final targetPos = (x: cell.gridX, y: cell.gridY);

    if (!_isReachable(targetPos)) {
      // 不可达 → 放弃当前单位，焦点切到点击的格子
      board.focusCell = cell;
      return false;
    }

    // 检查目标位置是否被可见单位阻挡
    final targetUnit = board.unitLayer.getUnitAt(targetPos.x, targetPos.y);
    if (targetUnit != null) {
      if (targetUnit.state != state) {
        final cellState = board.gameMap.getCell(targetPos.x, targetPos.y);
        if (cellState.isCenterVisible) {
          // 被可见单位阻挡 → 焦点切到该格子
          board.focusCell = cell;
          return false;
        }
      } else {
        board.focusCell = null;
        return false;
      }
    }

    // 可达且未阻挡
    if (state.previewPosition?.x == targetPos.x && state.previewPosition?.y == targetPos.y) {
      _confirmMovement(state, board);
      return true;
    } else {
      state.previewPosition = targetPos;
      board.updateRangeLayer();
      board.updatePreviewUnit();
      return false;
    }
  }

  bool _isReachable(Position pos) {
    for (final (path, _) in _currentPaths) {
      if (path.isNotEmpty) {
        final end = path.last;
        if (end.x == pos.x && end.y == pos.y) return true;
      }
    }
    return false;
  }

  Future<void> _confirmMovement(UnitState state, BoardComponent board) async {
    final target = state.previewPosition;
    if (target == null) return;

    // Find path
    List<Position>? path;
    for (final (p, _) in _currentPaths) {
      if (p.isNotEmpty && p.last.x == target.x && p.last.y == target.y) {
        path = p;
        break;
      }
    }

    if (path != null) {
      final unitComponent = board.unitLayer.getUnitAt(state.x, state.y);
      if (unitComponent == null) return;

      board.focusCell = null;

      for (int i = 1; i < path.length; i++) {
        if (state.currentActionPoints <= 0) break;

        final nextPoint = path[i];

        // 逐步验证：检查下一步是否被阻挡
        if (board.gameMap.blocksPass(nextPoint.x, nextPoint.y)) break;

        final otherUnit = board.unitLayer.getUnitAt(nextPoint.x, nextPoint.y);
        if (otherUnit != null && otherUnit != unitComponent) break;

        // 执行移动
        final targetPos = Vector2(
          (nextPoint.x + 0.5) * CellComponent.cellSize,
          (nextPoint.y + 0.5) * CellComponent.cellSize,
        );

        final completer = Completer<void>();
        board.add(
          MoveToEffect(
            targetPos,
            EffectController(speed: GameConstants.moveSpeed),
            target: unitComponent,
            onComplete: () {
              state.x = nextPoint.x;
              state.y = nextPoint.y;
              state.currentActionPoints--;
              board.updateFog();
              completer.complete();
            },
          ),
        );

        await completer.future;
      }

      // 重置技能并重新聚焦到移动后的位置
      state.focusSkill = state.unit.moveSkill;
      board.focusCell = board.gridLayer.getCell(state.x, state.y);
    }
  }
}
