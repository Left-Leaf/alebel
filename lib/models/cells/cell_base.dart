import 'dart:ui';
import '../../core/battle/battle_api.dart';
import '../../core/unit/unit_state.dart';

part 'ground_cell.dart';
part 'wall_cell.dart';
part 'water_cell.dart';
part 'forest_cell.dart';

/// 地图单元格数据模型（静态配置）
abstract class Cell {
  /// 是否阻止视线
  final bool blocksVision;

  /// 是否阻止移动
  final bool blocksMovement;

  /// 单位是否能驻足
  final bool canStand;

  // 调试或序列化用的名称
  final String name;

  const Cell({
    required this.name,
    this.blocksVision = false,
    this.blocksMovement = false,
    this.canStand = true,
  });

  /// 移动消耗的行动点（默认 1）
  int get moveCost => 1;

  /// 单位进入此格时调用
  Future<void> onUnitEnter(UnitState unit, {BattleAPI? api}) async {}

  /// 单位回合开始时站在此格触发
  Future<void> onTurnStart(UnitState unit, {BattleAPI? api}) async {}
}

/// 自定义 Canvas 绘制混入
mixin RenderCell on Cell {
  void render(Canvas canvas, Size size);
}

/// 纹理材质混入，提供图片资源路径
mixin SpriteCell on Cell {
  String get imagePath;
}
