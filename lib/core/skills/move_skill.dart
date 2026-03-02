part of 'skill.dart';

class MoveSkill extends Skill {
  @override
  String get name => 'Move';

  List<(List<Position>, PathCertainty)> _currentPaths = [];
  Position? _lastCalcPos;
  int? _lastPoints;

  void _ensurePaths(UnitState state, GameMap gameMap) {
    final startPos = (x: state.x, y: state.y);
    final points = state.currentActionPoints;
    if (_lastCalcPos?.x != state.x ||
        _lastCalcPos?.y != state.y ||
        _lastPoints != points ||
        _currentPaths.isEmpty) {
      _currentPaths = gameMap.getMovablePositions(startPos, points);
      _lastCalcPos = startPos;
      _lastPoints = points;
    }
  }

  @override
  List<({Position pos, HighlightType type})> getHighlightPositions(
      UnitState state, SkillContext ctx) {
    final highlights = <({Position pos, HighlightType type})>[];

    _ensurePaths(state, ctx.gameMap);

    final cellCertainty = <Position, PathCertainty>{};
    for (final (path, certainty) in _currentPaths) {
      for (final pos in path) {
        final existing = cellCertainty[pos];
        if (existing == null || certainty == PathCertainty.confirmed) {
          cellCertainty[pos] = certainty;
        }
      }
    }
    cellCertainty.remove((x: state.x, y: state.y));

    for (final entry in cellCertainty.entries) {
      highlights.add((
        pos: entry.key,
        type: entry.value == PathCertainty.confirmed
            ? HighlightType.moveConfirmed
            : HighlightType.moveUncertain,
      ));
    }

    if (state.previewPosition != null) {
      final attackablePositions = Skill.getPositionsInRange(
        state.previewPosition!, state.unit.attackRange,
        mapWidth: ctx.gameMap.width, mapHeight: ctx.gameMap.height,
      );

      for (final pos in attackablePositions) {
        highlights.add((pos: pos, type: HighlightType.attack));
      }
    }

    return highlights;
  }

  @override
  Future<bool> onTap(UnitState state, Position target, BattleAPI api) async {
    if (api.activeUnit != state) {
      api.setFocus(target);
      return false;
    }

    _ensurePaths(state, api.gameMap);

    if (!_isReachable(target)) {
      api.setFocus(target);
      return false;
    }

    // 检查目标位置是否被可见单位阻挡
    final targetUnit = api.getUnitAt(target.x, target.y);
    if (targetUnit != null) {
      if (targetUnit != state) {
        final cellState = api.gameMap.getCell(target.x, target.y);
        if (cellState.isCenterVisible) {
          api.setFocus(target);
          return false;
        }
      } else {
        api.setFocus(null);
        return false;
      }
    }

    // 可达且未阻挡
    if (state.previewPosition?.x == target.x &&
        state.previewPosition?.y == target.y) {
      // 第二次点击同一位置 → 确认移动
      final path = _findPath(target);
      if (path != null) {
        api.setFocus(null);
        await api.moveUnit(state, path);
        api.setFocus((x: state.x, y: state.y));
        return true;
      }
      return false;
    }

    // 第一次点击 → 预览
    api.setPreview(state, target);
    return false;
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

  List<Position>? _findPath(Position target) {
    for (final (p, _) in _currentPaths) {
      if (p.isNotEmpty && p.last.x == target.x && p.last.y == target.y) {
        return p;
      }
    }
    return null;
  }
}
