import 'cell.dart';
import 'entity.dart';
import 'tile_state.dart';

/// 地图区块
///
/// 16×16 的三层数据结构：
/// - 地形层（terrain）：密集二维矩阵，每格都有 [Cell]
/// - 实体层（entities）：稀疏映射，少数格子有 [Entity]
/// - 状态层（states）：稀疏映射，少数格子有 [TileState]
class MapChunk {
  static const int size = 16;

  /// chunk 在 chunk 网格中的坐标
  final int chunkX;
  final int chunkY;

  /// 地形层：size × size 密集矩阵，terrain[localY][localX]
  final List<List<Cell>> terrain;

  /// 实体层：稀疏映射，(localX, localY) → Entity
  final Map<(int, int), Entity> entities;

  /// 状态层：稀疏映射，(localX, localY) → TileState
  final Map<(int, int), TileState> states;

  MapChunk({
    required this.chunkX,
    required this.chunkY,
    required this.terrain,
    Map<(int, int), Entity>? entities,
    Map<(int, int), TileState>? states,
  })  : entities = entities ?? {},
        states = states ?? {} {
    if (terrain.length != size) {
      throw ArgumentError(
        'Terrain row count (${terrain.length}) must be $size',
      );
    }
    for (var y = 0; y < size; y++) {
      if (terrain[y].length != size) {
        throw ArgumentError(
          'Terrain row $y has ${terrain[y].length} columns, expected $size',
        );
      }
    }
  }

  /// 获取地形
  Cell getCell(int localX, int localY) {
    assert(localX >= 0 && localX < size && localY >= 0 && localY < size);
    return terrain[localY][localX];
  }

  /// 设置地形
  void setCell(int localX, int localY, Cell cell) {
    assert(localX >= 0 && localX < size && localY >= 0 && localY < size);
    terrain[localY][localX] = cell;
  }

  /// 获取实体（可能为空）
  Entity? getEntity(int localX, int localY) {
    return entities[(localX, localY)];
  }

  /// 获取状态（可能为空）
  TileState? getState(int localX, int localY) {
    return states[(localX, localY)];
  }
}
