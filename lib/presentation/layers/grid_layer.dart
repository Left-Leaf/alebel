import 'package:flame/components.dart';
import '../../game/alebel_game.dart';
import '../components/cell_component.dart';

class GridLayer extends PositionComponent with HasGameReference<AlebelGame> {
  final Map<({int x, int y}), CellComponent> cells = {};

  GridLayer();

  void addCell(CellComponent cell) {
    cells[(x: cell.gridX, y: cell.gridY)] = cell;
    add(cell);
  }

  CellComponent? getCell(int x, int y) => cells[(x: x, y: y)];
}
