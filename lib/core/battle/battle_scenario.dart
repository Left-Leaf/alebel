import '../../models/units/unit_base.dart';
import '../map/board.dart';

/// 单位生成配置
class UnitSpawn {
  /// 单位定义
  final Unit unit;

  /// 相对于玩家位置的偏移量
  final Position offset;

  const UnitSpawn({required this.unit, required this.offset});
}

/// 战斗场景配置
///
/// 描述一场战斗的单位配置。内容创作者只需定义此数据对象，
/// 框架负责根据配置生成单位和运行战斗。
class BattleScenario {
  /// 敌方单位列表
  final List<UnitSpawn> enemies;

  /// 额外的己方/盟友单位列表
  final List<UnitSpawn> allies;

  const BattleScenario({
    required this.enemies,
    this.allies = const [],
  });
}
