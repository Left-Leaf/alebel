import '../../common/constants.dart';
import 'cell_state.dart';
import '../../models/cells/cell_registry.dart';
import 'board.dart';

/// 地图数据模型
/// 包含地图的尺寸和所有单元格的详细信息
class GameMap implements BoardImpl {
  @override
  final int width;
  @override
  final int height;
  final List<List<CellState>> _cells;

  /// 基础构造函数
  GameMap._({required this.width, required this.height, required List<List<CellState>> cells})
    : _cells = cells;

  /// 从整数矩阵创建地图
  /// [matrix] 是一个二维数组，结构为 matrix[y][x]，即 List of Rows。
  /// 每一个整数代表一个 Cell ID。
  factory GameMap.fromMatrix(List<List<int>> matrix, CellRegistry registry) {
    if (matrix.isEmpty || matrix[0].isEmpty) {
      throw ArgumentError('Matrix cannot be empty');
    }

    final height = matrix.length;
    final width = matrix[0].length;

    // 创建列优先的存储结构 (List<List<CellState>> _cells[x][y])
    // 因为我们的内部逻辑是 getCell(x, y)
    final cells = List.generate(
      width,
      (x) => List.generate(height, (y) {
        // matrix 是按行存储的，所以是 matrix[y][x]
        final cellId = matrix[y][x];
        final cellConfig = registry.get(cellId);
        return CellState(cell: cellConfig, x: x, y: y);
      }),
    );

    return GameMap._(width: width, height: height, cells: cells);
  }

  /// 获取指定坐标的单元格数据
  CellState getCell(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      throw RangeError('Coordinate ($x, $y) is out of map bounds');
    }
    return _cells[x][y];
  }

  /// 方便的工厂方法：创建一个默认的标准地图
  ///
  /// [generator] 可选的地图生成函数，接收 (x, y, size, border) 返回 Cell ID。
  /// 默认生成外围墙壁 + 空白内部。
  factory GameMap.standard(
    CellRegistry registry, {
    int size = GameConstants.standardMapSize,
    int border = GameConstants.standardMapBorder,
    int Function(int x, int y, int size, int border)? generator,
  }) {
    final gen = generator ?? _defaultGenerator;
    final matrix = List.generate(
      size,
      (y) => List.generate(size, (x) => gen(x, y, size, border)),
    );
    return GameMap.fromMatrix(matrix, registry);
  }

  /// 默认地图生成器：外围墙壁，内部空地
  static int _defaultGenerator(int x, int y, int size, int border) {
    if (x < border || x >= size - border || y < border || y >= size - border) {
      return 1; // Wall
    }
    return 0; // Ground
  }

  /// 更新迷雾状态
  /// 将所有 visible 变为 explored，然后重新计算所有单位的视野
  void updateFog(List<({int x, int y, int range})> visionSources) {
    // 1. 将所有当前可见 (visible) 的格子重置为已探索 (explored)
    //    未知 (unknown) 的保持未知
    //    重置单位可见性
    for (var col in _cells) {
      for (var cell in col) {
        if (cell.fogState == FogState.visible) {
          cell.fogState = FogState.explored;
        }
        cell.isCenterVisible = false;
      }
    }

    // 2. 根据视野源重新点亮区域
    for (final source in visionSources) {
      final visiblePositions = getVisiblePositions((x: source.x, y: source.y), source.range);

      // 包含中心点自己
      final sourceCell = getCell(source.x, source.y);
      sourceCell.fogState = FogState.visible;
      sourceCell.isCenterVisible = true;

      for (final entry in visiblePositions) {
        final pos = entry.position;

        final cell = getCell(pos.x, pos.y);

        // 边缘可见 -> 不显示迷雾 (visible)
        if (entry.edge) {
          cell.fogState = FogState.visible;
        }

        // 中心可见 -> 显示Unit (isCenterVisible)
        if (entry.center) {
          cell.isCenterVisible = true;
        }
      }
    }
  }

  @override
  bool blocksPass(int x, int y) {
    final cell = getCell(x, y);
    // 如果是未知区域，视为可通过（当作空方格）
    if (cell.fogState == FogState.unknown) return false;
    return cell.blocksMovement;
  }

  @override
  bool canStand(int x, int y) {
    final cell = getCell(x, y);
    // 如果是未知区域，视为可停留
    if (cell.fogState == FogState.unknown) return true;
    return cell.canStand;
  }

  @override
  bool blocksVision(int x, int y) {
    final cell = getCell(x, y);
    // 如果是未知区域，视为不阻挡视线（当作空方格）
    if (cell.fogState == FogState.unknown) return false;
    return cell.blocksVision;
  }

  @override
  bool isCellKnown(int x, int y) {
    final cell = getCell(x, y);
    return cell.fogState != FogState.unknown;
  }

  @override
  int getMoveCost(int x, int y) {
    final cell = getCell(x, y);
    if (cell.fogState == FogState.unknown) return 1;
    return cell.cell.moveCost;
  }
}
