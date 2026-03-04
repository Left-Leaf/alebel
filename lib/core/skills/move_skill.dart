part of 'skill.dart';

class MoveSkill extends Skill {
  @override
  String get name => 'Move';

  @override
  int get maxUsesPerTurn => 1;

  static List<(List<Position>, PathCertainty)> _calcPaths(UnitState state, GameMap gameMap) {
    return gameMap.getMovablePositions((x: state.x, y: state.y), state.currentActionPoints);
  }

  @override
  List<({Position pos, Color color})> getHighlightPositions(
      UnitState state, SkillContext ctx) {
    final highlights = <({Position pos, Color color})>[];
    final paths = _calcPaths(state, ctx.gameMap);

    final cellCertainty = <Position, PathCertainty>{};
    for (final (path, certainty) in paths) {
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
        color: entry.value == PathCertainty.confirmed
            ? AlebelTheme.highlightMoveConfirmed
            : AlebelTheme.highlightMoveUncertain,
      ));
    }

    if (state.previewPosition != null) {
      final attackablePositions = Skill.getPositionsInRange(
        state.previewPosition!, state.unit.attackRange,
        mapWidth: ctx.gameMap.width, mapHeight: ctx.gameMap.height,
      );

      for (final pos in attackablePositions) {
        highlights.add((pos: pos, color: AlebelTheme.highlightAttack));
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

    final paths = _calcPaths(state, api.gameMap);

    final reachablePath = _findPath(paths, target);
    if (reachablePath == null) {
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
      api.setFocus(null);
      await api.moveUnit(state, reachablePath);
      api.setFocus((x: state.x, y: state.y));
      return true;
    }

    // 第一次点击 → 预览
    api.setPreview(state, target);
    return false;
  }

  static List<Position>? _findPath(
      List<(List<Position>, PathCertainty)> paths, Position target) {
    for (final (p, _) in paths) {
      if (p.isNotEmpty && p.last.x == target.x && p.last.y == target.y) {
        return p;
      }
    }
    return null;
  }
}
