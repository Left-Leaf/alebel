import 'cell_base.dart';

class CellRegistry {
  final Map<int, Cell> _cells = {};

  /// 测试用同步构造函数
  CellRegistry.forTest(Map<int, Cell> cells) {
    _cells.addAll(cells);
  }

  CellRegistry();

  /// 注册所有 Cell
  void register(Map<int, Cell> cells) {
    _cells.addAll(cells);
  }

  Cell get(int id) {
    return _cells[id] ?? const GroundCell();
  }
}
