import 'dart:ui';

import '../framework/map/cell.dart';
import '../framework/map/cell_registry.dart';

export 'empty_cell.dart';
export 'wall_cell.dart';
export 'wood_cell.dart';
export 'stone_cell.dart';
export 'steel_cell.dart';
export 'water_cell.dart';

import 'empty_cell.dart';
import 'wall_cell.dart';
import 'wood_cell.dart';
import 'stone_cell.dart';
import 'steel_cell.dart';
import 'water_cell.dart';

/// 所有预设 Cell 实例（按 ID 排列）
const List<Cell> presetCells = [
  EmptyCell(),  // 0
  WallCell(),   // 1
  WoodCell(),   // 2
  StoneCell(),  // 3
  SteelCell(),  // 4
  WaterCell(),  // 5
];

/// 构建包含所有预设 Cell 的 [CellRegistry]
CellRegistry buildPresetCellRegistry() {
  return CellRegistry.from({
    for (final cell in presetCells) cell.id: cell,
  });
}

/// 所有预设 Cell 的编辑器回退颜色映射
const Map<int, Color> presetCellColors = {
  0: EmptyCell.color,
  1: WallCell.color,
  2: WoodCell.color,
  3: StoneCell.color,
  4: SteelCell.color,
  5: WaterCell.color,
};

/// 所有预设 Cell 的材质图路径映射（Flame 相对路径）
/// 没有材质图的 Cell 不包含在此映射中。
const Map<int, String> presetCellImagePaths = {
  1: WallCell.imagePath,
  2: WoodCell.imagePath,
  3: StoneCell.imagePath,
  4: SteelCell.imagePath,
  5: WaterCell.imagePath,
};
