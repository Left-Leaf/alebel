import 'package:alebel/core/map/board.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal BoardImpl for testing pathfinding and vision
class TestBoard implements BoardImpl {
  @override
  final int width;
  @override
  final int height;

  final Set<Position> _walls;
  final Set<Position> _unknownCells;

  TestBoard({
    required this.width,
    required this.height,
    Set<Position>? walls,
    Set<Position>? unknownCells,
  }) : _walls = walls ?? {},
       _unknownCells = unknownCells ?? {};

  @override
  bool blocksPass(int x, int y) => _walls.contains((x: x, y: y));

  @override
  bool blocksVision(int x, int y) => _walls.contains((x: x, y: y));

  @override
  bool canStand(int x, int y) => !_walls.contains((x: x, y: y));

  @override
  bool isCellKnown(int x, int y) => !_unknownCells.contains((x: x, y: y));
}

void main() {
  group('BFS pathfinding (getMovablePositions)', () {
    test('open field returns correct number of reachable positions', () {
      final board = TestBoard(width: 10, height: 10);
      final paths = board.getMovablePositions((x: 5, y: 5), 2);

      // Collect unique endpoints
      final endpoints = <Position>{};
      for (final (path, _) in paths) {
        endpoints.add(path.last);
      }

      // With range 2 in open field from (5,5), should reach:
      // range 0: 1 position (self)
      // range 1: 4 positions
      // range 2: 8 positions
      // Total: 13
      expect(endpoints.length, equals(13));
    });

    test('walls block movement', () {
      final board = TestBoard(
        width: 10,
        height: 10,
        walls: {(x: 5, y: 4), (x: 5, y: 6), (x: 4, y: 5), (x: 6, y: 5)},
      );

      final paths = board.getMovablePositions((x: 5, y: 5), 3);
      final endpoints = <Position>{};
      for (final (path, _) in paths) {
        endpoints.add(path.last);
      }

      // Completely surrounded, can only reach self
      expect(endpoints.length, equals(1));
      expect(endpoints.first, equals((x: 5, y: 5)));
    });

    test('range 0 returns only start position', () {
      final board = TestBoard(width: 10, height: 10);
      final paths = board.getMovablePositions((x: 3, y: 3), 0);

      final endpoints = <Position>{};
      for (final (path, _) in paths) {
        endpoints.add(path.last);
      }

      expect(endpoints.length, equals(1));
      expect(endpoints.first, equals((x: 3, y: 3)));
    });

    test('corner position limits reachable area', () {
      final board = TestBoard(width: 10, height: 10);
      final paths = board.getMovablePositions((x: 0, y: 0), 1);

      final endpoints = <Position>{};
      for (final (path, _) in paths) {
        endpoints.add(path.last);
      }

      // From corner (0,0) with range 1: self + (1,0) + (0,1) = 3
      expect(endpoints.length, equals(3));
    });
  });

  group('Vision (getVisiblePositions)', () {
    test('open field visibility', () {
      final board = TestBoard(width: 10, height: 10);
      final visible = board.getVisiblePositions((x: 5, y: 5), 3);

      // Should have multiple visible positions
      expect(visible.isNotEmpty, isTrue);
    });

    test('wall blocks vision', () {
      // Place a wall at (6,5) and check if (7,5) is center-visible
      final board = TestBoard(
        width: 10,
        height: 10,
        walls: {(x: 6, y: 5)},
      );

      final visible = board.getVisiblePositions((x: 5, y: 5), 5);
      final behindWall = visible.where((v) =>
        v.position.x == 7 && v.position.y == 5
      );

      // (7,5) should not be center-visible through wall at (6,5)
      if (behindWall.isNotEmpty) {
        expect(behindWall.first.center, isFalse);
      }
    });

    test('getVisionState for same position returns fully visible', () {
      final board = TestBoard(width: 10, height: 10);
      final state = board.getVisionState((x: 5, y: 5), (x: 5, y: 5));

      expect(state.center, isTrue);
      expect(state.edge, isTrue);
    });
  });

  group('Path certainty', () {
    test('all-known path is confirmed', () {
      final board = TestBoard(width: 10, height: 10);
      final paths = board.getMovablePositions((x: 5, y: 5), 2);
      // 无 unknown 格子，所有路径应为 confirmed
      for (final (_, certainty) in paths) {
        expect(certainty, equals(PathCertainty.confirmed));
      }
    });

    test('path through unknown cell is uncertain', () {
      final board = TestBoard(
        width: 10, height: 10,
        unknownCells: {(x: 6, y: 5)},
      );
      final paths = board.getMovablePositions((x: 5, y: 5), 3);

      // 经过 (6,5) 的路径应标记为 uncertain
      for (final (path, certainty) in paths) {
        final goesThrough = path.any((p) => p.x == 6 && p.y == 5);
        if (goesThrough) {
          expect(certainty, equals(PathCertainty.uncertain));
        }
      }
    });

    test('uncertainty propagates along path', () {
      final board = TestBoard(
        width: 10, height: 10,
        unknownCells: {(x: 6, y: 5)},
      );
      final paths = board.getMovablePositions((x: 5, y: 5), 3);

      // (7,5) 的路径必然经过 (6,5)，也应为 uncertain
      final pathTo7_5 = paths.where((e) {
        final path = e.$1;
        return path.last.x == 7 && path.last.y == 5;
      });
      if (pathTo7_5.isNotEmpty) {
        expect(pathTo7_5.first.$2, equals(PathCertainty.uncertain));
      }
    });
  });
}
