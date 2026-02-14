import 'package:flame/components.dart';
import '../../game/alebel_game.dart';
import '../components/unit_component.dart';

class UnitLayer extends PositionComponent with HasGameReference<AlebelGame> {
  final List<UnitComponent> units = [];

  void addUnit(UnitComponent unit) {
    units.add(unit);
    add(unit);
  }

  void removeUnit(UnitComponent unit) {
    units.remove(unit);
    remove(unit);
  }

  UnitComponent? getUnitAt(int x, int y) {
    for (final unit in units) {
      if (unit.gridX == x && unit.gridY == y) {
        return unit;
      }
    }
    return null;
  }
}
