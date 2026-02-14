import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../game/alebel_game.dart';
import '../../core/unit/unit_state.dart';
import '../../models/units/unit_base.dart';
import 'cell_component.dart';

class UnitComponent extends PositionComponent
    with HasGameReference<AlebelGame> {
  final UnitState state;

  int get gridX => state.x;
  int get gridY => state.y;
  Color get color => state.unit.color;
  UnitFaction get faction => state.unit.faction;

  // 视觉透明度 (用于幽灵模式)
  double visualOpacity = 1.0;

  UnitComponent({required this.state})
    : super(
        position: Vector2(
          (state.x + 0.5) * CellComponent.cellSize,
          (state.y + 0.5) * CellComponent.cellSize,
        ),
        size: Vector2.all(CellComponent.cellSize),
        anchor: Anchor.center,
      );

  @override
  void render(Canvas canvas) {
    // 检查迷雾状态
    // 通过 game 引用获取地图数据
    final cellState = game.gameMap.getCell(gridX, gridY);

    // 如果单位所在的格子不是中心可见，且不是玩家单位，则不渲染
    // 玩家单位总是渲染（哪怕在迷雾中，可能是为了调试或者特殊效果）
    // 幽灵单位（visualOpacity < 1.0）通常是玩家操作产生的，也应该渲染
    
    // 逻辑：
    // 1. 如果是 preview/ghost (visualOpacity < 1.0)，渲染。
    // 2. 如果是玩家单位，渲染。
    // 3. 如果是敌方单位，且格子 isCenterVisible，渲染。
    
    bool shouldRender = false;
    
    if (visualOpacity < 0.99) {
      shouldRender = true;
    } else if (faction == UnitFaction.player) {
      shouldRender = true;
    } else if (cellState.isCenterVisible) {
      shouldRender = true;
    }

    if (!shouldRender) return;

    // 绘制单位：一个简单的圆形，略小于格子
    final radius = size.x / 2 * 0.7; // 70% 大小

    // 绘制阴影
    canvas.drawCircle(
      Offset(size.x / 2 + 2, size.y / 2 + 2),
      radius,
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    // 绘制主体
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius,
      Paint()..color = color.withOpacity(visualOpacity),
    );

    // 绘制边缘
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.8 * visualOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  // 计算单位的矩形区域
  Rect get rect => Rect.fromCenter(
    center: position.toOffset(),
    width: size.x,
    height: size.y,
  );
}
