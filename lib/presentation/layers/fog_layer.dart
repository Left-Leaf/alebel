import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../core/map/cell_state.dart'; // 导入 FogState
import '../../core/map/game_map.dart';
import '../components/cell_component.dart';

class FogLayer extends PositionComponent {
  final int mapWidth;
  final int mapHeight;
  final GameMap map;

  FogLayer({required this.map}) : mapWidth = map.width, mapHeight = map.height;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // 创建每个格子的迷雾组件
    for (int x = 0; x < mapWidth; x++) {
      for (int y = 0; y < mapHeight; y++) {
        add(
          FogCellComponent(
            cellState: map.getCell(x, y),
            position: Vector2(
              x * CellComponent.cellSize,
              y * CellComponent.cellSize,
            ),
            size: Vector2.all(CellComponent.cellSize),
          ),
        );
      }
    }
  }
}

class FogCellComponent extends PositionComponent with HasPaint {
  final CellState cellState;
  @override
  double opacity = 1;

  FogCellComponent({
    required this.cellState,
    required super.position,
    required super.size,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // 初始设置
    opacity = _getOpacityForState(cellState.fogState);
  }

  double _getOpacityForState(FogState state) {
    switch (state) {
      case FogState.visible:
        return 0.0;
      case FogState.explored:
        return 0.5;
      case FogState.unknown:
        return 1.0;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    double targetOpacity = _getOpacityForState(cellState.fogState);
    if (targetOpacity != opacity) {
      removeAll(children.whereType<Effect>().toList());
      add(OpacityEffect.to(targetOpacity, EffectController(duration: 0.25)));
    }
  }

  @override
  void render(Canvas canvas) {
    // 如果完全透明，则不绘制
    if (opacity <= 0.01) return;

    final paint = Paint()..color = Colors.black.withOpacity(opacity);
    canvas.drawRect(size.toRect(), paint);
  }
}
