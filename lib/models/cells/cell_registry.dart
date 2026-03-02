import 'package:flame/game.dart';

import 'cell_base.dart';

class CellRegistry {
  final Map<int, Cell> _cells = {};

  /// 测试用同步构造函数
  CellRegistry.forTest(Map<int, Cell> cells) {
    _cells.addAll(cells);
  }

  CellRegistry();

  /// 注册所有 Cell 并为 SpriteCell 加载精灵图
  Future<void> register(FlameGame game, Map<int, Cell> cells) async {
    _cells.addAll(cells);
    for (final cell in _cells.values) {
      if (cell is SpriteCell) {
        await cell.loadSprite(game.images);
      }
    }
  }

  Cell get(int id) {
    return _cells[id] ?? GroundCell();
  }
}
