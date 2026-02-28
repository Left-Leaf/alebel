import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../game/alebel_game.dart';
import '../../presentation/components/cell_component.dart';
import '../map/board.dart';
import '../unit/unit_state.dart';

part 'attack_skill.dart';
part 'move_skill.dart';

sealed class Skill {
  String get name;

  bool onCellTap(UnitState state, CellComponent cell, AlebelGame game);

  List<({int x, int y, Color color})> getHighlightPositions(UnitState state, AlebelGame game);
}
