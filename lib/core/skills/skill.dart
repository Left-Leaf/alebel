import 'dart:ui';

import '../../common/theme.dart';
import '../battle/battle_api.dart';
import '../map/board.dart';
import '../map/game_map.dart';
import '../unit/unit_state.dart';

part 'attack_skill.dart';
part 'move_skill.dart';

/// 技能查询上下文（用于 getHighlightPositions，只读）
class SkillContext {
  final GameMap gameMap;
  final UnitState? activeUnit;
  final UnitState? Function(int x, int y) getUnitAt;

  const SkillContext({required this.gameMap, required this.activeUnit, required this.getUnitAt});
}

abstract class Skill {
  String get name;

  /// AP 消耗（0 = 免费）
  int get cost => 0;

  /// 使用后冷却回合数（0 = 无冷却）
  int get cooldown => 0;

  /// 每回合最大使用次数（-1 = 无限制）
  int get maxUsesPerTurn => -1;

  /// 处理点击事件，通过 [api] 直接执行效果和控制交互状态。
  /// 返回 true 表示技能执行了实际动作（需记录），false 表示仅交互变更。
  Future<bool> onTap(UnitState state, Position target, BattleAPI api);

  /// 返回高亮位置 + 颜色
  List<({Position pos, Color color})> getHighlightPositions(
    UnitState state,
    SkillContext ctx,
  );

  /// 计算以 [center] 为中心、曼哈顿距离 [range] 内的所有位置（排除中心）
  static List<Position> getPositionsInRange(
    Position center,
    int range, {
    required int mapWidth,
    required int mapHeight,
  }) {
    final positions = <Position>[];
    for (var dx = -range; dx <= range; dx++) {
      for (var dy = -range; dy <= range; dy++) {
        if (dx.abs() + dy.abs() <= range) {
          final x = center.x + dx;
          final y = center.y + dy;
          if (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight) {
            if (dx == 0 && dy == 0) continue;
            positions.add((x: x, y: y));
          }
        }
      }
    }
    return positions;
  }
}
