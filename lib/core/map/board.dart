typedef Position = ({int x, int y});
typedef VisionState = ({Position position, bool center, bool edge});

abstract class BoardImpl {
  int get width;

  int get height;

  bool blocksPass(int x, int y);

  bool blocksVision(int x, int y);

  bool canStand(int x, int y);
}

extension BoardExtension on BoardImpl {
  /// 计算所有可移动位置
  List<List<Position>> getMovablePositions(Position position, int power) {
    List<List<Position>> paths = [];
    final queue = <(Position, List<Position>)>[];
    final visited = <Position>{};

    // Initial state
    queue.add((position, [position]));
    visited.add(position);
    paths.add([position]);

    while (queue.isNotEmpty) {
      final (current, path) = queue.removeAt(0);

      // If we have reached max power, we cannot extend further
      if (path.length - 1 >= power) continue;

      final directions = [(x: 0, y: -1), (x: 0, y: 1), (x: -1, y: 0), (x: 1, y: 0)];

      for (final dir in directions) {
        final nextX = current.x + dir.x;
        final nextY = current.y + dir.y;

        // Check bounds
        if (nextX < 0 || nextX >= width || nextY < 0 || nextY >= height) {
          continue;
        }

        // Check obstacles
        if (blocksPass(nextX, nextY)) continue;

        final nextPos = (x: nextX, y: nextY);

        if (!visited.contains(nextPos)) {
          visited.add(nextPos);
          final newPath = List<Position>.from(path)..add(nextPos);

          // Check if standable (can stop here)
          if (canStand(nextX, nextY)) {
            paths.add(newPath);
          }

          // Add to queue to continue searching
          queue.add((nextPos, newPath));
        }
      }
    }

    return paths;
  }

  /// 计算所有可见位置
  List<VisionState> getVisiblePositions(Position center, int range) {
    final visible = <VisionState>[];

    for (var dx = -range + 1; dx < range; dx++) {
      final maxDy = range - dx.abs();
      for (var dy = -maxDy + 1; dy < maxDy; dy++) {
        final x = center.x + dx;
        final y = center.y + dy;

        if (x < 0 || x >= width || y < 0 || y >= height) continue;

        final target = (x: x, y: y);
        final state = getVisionState(center, target);

        // 只要中心可见或者边缘可见，就认为该方格可见
        if (state.center || state.edge) {
          visible.add(state);
        }
      }
    }

    return visible;
  }

  /// 获取两点之间的视线状态
  VisionState getVisionState(Position start, Position end) {
    if (start.x == end.x && start.y == end.y) {
      return (position: end, center: true, edge: true);
    }

    final centerVisible = _checkCenterVisibility(start, end);
    final edgeVisible = _checkEdgeVisibility(start, end);

    return (position: end, center: centerVisible, edge: edgeVisible);
  }

  bool _checkCenterVisibility(Position start, Position end) {
    return _traceRay(start.x + 0.5, start.y + 0.5, end.x + 0.5, end.y + 0.5, start, end);
  }

  bool _checkEdgeVisibility(Position start, Position end) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;

    // 目标格子的四个角坐标
    final x = end.x.toDouble();
    final y = end.y.toDouble();

    final tl = (x: x, y: y); // Top-Left
    final tr = (x: x + 1.0, y: y); // Top-Right
    final bl = (x: x, y: y + 1.0); // Bottom-Left
    final br = (x: x + 1.0, y: y + 1.0); // Bottom-Right

    // 辅助函数：检查到某个角是否可见
    bool isVisible(({double x, double y}) p) {
      return _traceRay(start.x + 0.5, start.y + 0.5, p.x, p.y, start, end);
    }

    // 1. 位于相同横轴或纵轴
    if (dx == 0) {
      // 垂直方向
      if (dy > 0) {
        // 下方 (South) -> 检查上边 (TL, TR)
        return isVisible(tl) && isVisible(tr);
      } else {
        // 上方 (North) -> 检查下边 (BL, BR)
        return isVisible(bl) && isVisible(br);
      }
    }
    if (dy == 0) {
      // 水平方向
      if (dx > 0) {
        // 右方 (East) -> 检查左边 (TL, BL)
        return isVisible(tl) && isVisible(bl);
      } else {
        // 左方 (West) -> 检查右边 (TR, BR)
        return isVisible(tr) && isVisible(br);
      }
    }

    // 2. 位于斜角
    if (dx > 0 && dy > 0) {
      // 右下 (SE)
      // 最近角: TL
      // 临近边: 上边(TL-TR), 左边(TL-BL)
      if (!isVisible(tl)) return false;
      return isVisible(tr) || isVisible(bl);
    }
    if (dx < 0 && dy > 0) {
      // 左下 (SW)
      // 最近角: TR
      // 临近边: 上边(TL-TR), 右边(TR-BR)
      if (!isVisible(tr)) return false;
      return isVisible(tl) || isVisible(br);
    }
    if (dx > 0 && dy < 0) {
      // 右上 (NE)
      // 最近角: BL
      // 临近边: 下边(BL-BR), 左边(TL-BL)
      if (!isVisible(bl)) return false;
      return isVisible(br) || isVisible(tl);
    }
    if (dx < 0 && dy < 0) {
      // 左上 (NW)
      // 最近角: BR
      // 临近边: 下边(BL-BR), 右边(TR-BR)
      if (!isVisible(br)) return false;
      return isVisible(bl) || isVisible(tr);
    }

    return false;
  }

  /// 射线追踪检测
  bool _traceRay(
    double startX,
    double startY,
    double endX,
    double endY,
    Position startCell,
    Position endCell,
  ) {
    final dx = endX - startX;
    final dy = endY - startY;

    // 距离 heuristic
    final distance = dx.abs() + dy.abs();
    final steps = (distance * 3).ceil();

    if (steps <= 0) return true;

    final stepX = dx / steps;
    final stepY = dy / steps;

    var cx = startX;
    var cy = startY;

    for (var i = 1; i < steps; i++) {
      cx += stepX;
      cy += stepY;

      final curX = cx.floor();
      final curY = cy.floor();

      // 忽略起点
      if (curX == startCell.x && curY == startCell.y) continue;

      // 忽略终点（对于边缘检测，终点所在的格子不应该作为阻挡）
      // 注意：如果是检测中心点，endCell就是目标格子
      // 如果是检测角点，射线终点是角，不属于任何格子，但可能会穿过endCell的边缘
      // 这里统一忽略目标格子本身作为阻挡
      if (curX == endCell.x && curY == endCell.y) continue;

      // 检查越界
      if (curX < 0 || curX >= width || curY < 0 || curY >= height) continue;

      // 检查阻挡
      if (blocksVision(curX, curY)) return false;
    }

    return true;
  }
}
