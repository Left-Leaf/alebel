import '../buffs/buff.dart';
import '../map/board.dart';
import '../map/game_map.dart';
import '../skills/skill.dart';
import '../unit/unit_state.dart';

/// 战斗操作 API
///
/// 技能通过此接口执行游戏效果和控制交互状态。
/// 每个方法封装完整的操作链（动画、事件、状态更新），
/// 技能实现者无需了解框架内部细节。
abstract class BattleAPI {
  // ── 查询 ──

  /// 当前行动单位
  UnitState? get activeUnit;

  /// 获取指定位置的单位
  UnitState? getUnitAt(int x, int y);

  /// 地图数据
  GameMap get gameMap;

  // ── 交互控制 ──

  /// 设置焦点格子（null = 清除焦点）
  void setFocus(Position? target);

  /// 设置移动预览位置（显示投影单位 + 更新范围）
  void setPreview(UnitState caster, Position target);

  /// 清除移动预览
  void clearPreview(UnitState caster);

  /// 切换当前激活技能（更新范围显示）
  void switchSkill(UnitState caster, Skill skill);

  // ── 游戏效果 ──

  /// 沿路径移动单位（逐步动画 + 验证 + 扣 AP + 刷迷雾）
  Future<void> moveUnit(UnitState unit, List<Position> path);

  /// 对目标造成伤害（扣血 + 判死亡 + 发事件 + 判胜负）
  void damageUnit(UnitState target, int amount);

  /// 治疗目标（恢复 HP）
  void healUnit(UnitState target, int amount);

  /// 施加 Buff（自动触发属性重算）
  void addBuff(UnitState target, Buff buff);
}
