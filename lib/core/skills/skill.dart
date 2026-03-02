import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../common/constants.dart';
import '../../game/board_component.dart';
import '../../presentation/components/cell_component.dart';
import '../events/game_event.dart';
import '../map/board.dart';
import '../unit/unit_state.dart';

part 'attack_skill.dart';
part 'move_skill.dart';

sealed class Skill {
  String get name;

  bool onCellTap(UnitState state, CellComponent cell, BoardComponent board);

  List<({int x, int y, Color color})> getHighlightPositions(UnitState state, BoardComponent board);

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
