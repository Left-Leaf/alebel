import 'cell_base.dart';
import 'ground_cell.dart';
import 'wall_cell.dart';
import 'water_cell.dart';
import 'forest_cell.dart';

class CellRegistry {
  static final Map<int, Cell> _cells = {
    0: const GroundCell(),
    1: const WallCell(),
    2: const WaterCell(),
    3: const ForestCell(),
  };

  static void register(int id, Cell cell) {
    _cells[id] = cell;
  }

  static Cell get(int id) {
    return _cells[id] ?? const GroundCell();
  }
}
