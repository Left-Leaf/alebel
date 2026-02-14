import 'package:flutter/material.dart';

import '../../game/alebel_game.dart';
import '../../presentation/components/cell_component.dart';
import '../unit/unit_state.dart';

abstract class Skill {
  String get name;

  void onCellTap(UnitState state, CellComponent cell, AlebelGame game);

  List<({int x, int y, Color color})> getHighlightPositions(UnitState state, AlebelGame game);
}
