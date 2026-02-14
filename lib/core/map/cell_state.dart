import 'package:alebel/models/cells/cell_base.dart';

enum FogState {
  visible,   // 当前可见，完全透明
  explored,  // 已探索但当前不可见，半透明遮罩
  unknown,   // 未探索，完全不透明（黑色）
}

class CellState {
  final Cell cell;
  final int x;
  final int y;

  // 动态属性（运行时可能会改变）
  bool blocksVision;
  bool blocksMovement;
  bool canStand;

  // 迷雾状态
  FogState fogState = FogState.unknown;
  
  // 中心点可见性（决定单位是否可见）
  bool isCenterVisible = false;

  CellState({
    required this.cell,
    required this.x,
    required this.y,
  }) : blocksVision = cell.blocksVision,
       blocksMovement = cell.blocksMovement,
       canStand = cell.canStand;
}
