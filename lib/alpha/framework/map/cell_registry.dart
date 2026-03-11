import 'cell.dart';

/// 格子注册表
///
/// 将整数 ID 映射到 [Cell] 实例，用于地图反序列化。
/// 序列化方向通过 [Cell.id] 直接获取。
class CellRegistry {
  final Map<int, Cell> _cells = {};

  CellRegistry();

  CellRegistry.from(Map<int, Cell> cells) {
    _cells.addAll(cells);
  }

  void register(Map<int, Cell> cells) {
    _cells.addAll(cells);
  }

  /// 通过 ID 获取 Cell（反序列化）
  Cell get(int id) {
    final cell = _cells[id];
    if (cell == null) {
      throw ArgumentError('Unknown cell ID: $id');
    }
    return cell;
  }

  /// 返回所有注册的 Cell（编辑器调色板枚举用）
  Map<int, Cell> get entries => Map.unmodifiable(_cells);
}
