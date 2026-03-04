import 'package:alebel/core/map/cell_state.dart';
import 'package:alebel/core/map/game_map.dart';
import 'package:alebel/models/cells/cell_base.dart';
import 'package:alebel/models/cells/cell_registry.dart';
import 'package:flutter_test/flutter_test.dart';

CellRegistry _testRegistry() {
  return CellRegistry.forTest({
    0: GroundCell(),
    1: WallCell(),
    2: WaterCell(),
  });
}

void main() {
  group('GameMap.fromMatrix', () {
    test('creates map with correct dimensions', () {
      final registry = _testRegistry();
      final map = GameMap.fromMatrix([
        [0, 0, 0],
        [0, 1, 0],
        [0, 0, 0],
        [0, 0, 0],
      ], registry);

      expect(map.width, equals(3));
      expect(map.height, equals(4));
    });

    test('getCell returns correct cell type', () {
      final registry = _testRegistry();
      final map = GameMap.fromMatrix([
        [0, 1],
        [2, 0],
      ], registry);

      expect(map.getCell(0, 0).cell, isA<GroundCell>());
      expect(map.getCell(1, 0).cell, isA<WallCell>());
      expect(map.getCell(0, 1).cell, isA<WaterCell>());
      expect(map.getCell(1, 1).cell, isA<GroundCell>());
    });

    test('getCell throws on out of bounds', () {
      final registry = _testRegistry();
      final map = GameMap.fromMatrix([
        [0, 0],
        [0, 0],
      ], registry);

      expect(() => map.getCell(-1, 0), throwsA(isA<RangeError>()));
      expect(() => map.getCell(0, -1), throwsA(isA<RangeError>()));
      expect(() => map.getCell(2, 0), throwsA(isA<RangeError>()));
      expect(() => map.getCell(0, 2), throwsA(isA<RangeError>()));
    });

    test('empty matrix throws ArgumentError', () {
      final registry = _testRegistry();
      expect(
        () => GameMap.fromMatrix([], registry),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('GameMap blocking properties', () {
    test('blocksPass reflects cell type', () {
      final registry = _testRegistry();
      final map = GameMap.fromMatrix([
        [0, 1],
      ], registry);

      // Set to explored so blocksPass checks actual cell property
      map.getCell(0, 0).fogState = FogState.explored;
      map.getCell(1, 0).fogState = FogState.explored;

      expect(map.blocksPass(0, 0), isFalse); // Ground
      expect(map.blocksPass(1, 0), isTrue); // Wall
    });

    test('unknown fog treats cells as passable', () {
      final registry = _testRegistry();
      final map = GameMap.fromMatrix([
        [1], // Wall
      ], registry);

      // Default fog is unknown
      expect(map.getCell(0, 0).fogState, equals(FogState.unknown));
      expect(map.blocksPass(0, 0), isFalse); // Unknown = passable
    });

    test('canStand reflects cell type', () {
      final registry = _testRegistry();
      final map = GameMap.fromMatrix([
        [0, 2], // Ground, Water
      ], registry);

      map.getCell(0, 0).fogState = FogState.explored;
      map.getCell(1, 0).fogState = FogState.explored;

      expect(map.canStand(0, 0), isTrue); // Ground
      expect(map.canStand(1, 0), isFalse); // Water
    });

    test('blocksVision reflects cell type', () {
      final registry = _testRegistry();
      final map = GameMap.fromMatrix([
        [0, 1],
      ], registry);

      map.getCell(0, 0).fogState = FogState.explored;
      map.getCell(1, 0).fogState = FogState.explored;

      expect(map.blocksVision(0, 0), isFalse); // Ground
      expect(map.blocksVision(1, 0), isTrue); // Wall
    });
  });

  group('GameMap.updateFog', () {
    test('sets visible cells correctly', () {
      final registry = _testRegistry();
      final map = GameMap.fromMatrix([
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
      ], registry);

      map.updateFog([(x: 1, y: 1, range: 2)]);

      // Center should be visible
      expect(map.getCell(1, 1).fogState, equals(FogState.visible));
      expect(map.getCell(1, 1).isCenterVisible, isTrue);
    });

    test('visible becomes explored after second update without source', () {
      final registry = _testRegistry();
      final map = GameMap.fromMatrix([
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
      ], registry);

      // First update: make cells visible
      map.updateFog([(x: 1, y: 1, range: 2)]);
      expect(map.getCell(1, 1).fogState, equals(FogState.visible));

      // Second update: no sources => previously visible becomes explored
      map.updateFog([]);
      expect(map.getCell(1, 1).fogState, equals(FogState.explored));
      expect(map.getCell(1, 1).isCenterVisible, isFalse);
    });
  });

  group('GameMap.isCellKnown', () {
    test('returns false for unknown cells', () {
      final registry = _testRegistry();
      final map = GameMap.fromMatrix([
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
      ], registry);

      // 默认所有格子为 unknown
      expect(map.isCellKnown(1, 1), isFalse);
    });

    test('returns true after fog update', () {
      final registry = _testRegistry();
      final map = GameMap.fromMatrix([
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
      ], registry);

      map.updateFog([(x: 1, y: 1, range: 2)]);
      expect(map.isCellKnown(1, 1), isTrue);
    });
  });

  group('GameMap.standard', () {
    test('creates map with specified size', () {
      final registry = CellRegistry();
      registry.register({0: const GroundCell(), 1: const WallCell()});
      final map = GameMap.standard(registry, size: 10, border: 1);

      expect(map.width, equals(10));
      expect(map.height, equals(10));
    });

    test('default generator creates wall border and ground interior', () {
      final registry = CellRegistry();
      registry.register({0: const GroundCell(), 1: const WallCell()});
      final map = GameMap.standard(registry, size: 6, border: 1);

      // Border cells should be walls
      expect(map.getCell(0, 0).cell, isA<WallCell>());
      expect(map.getCell(5, 0).cell, isA<WallCell>());
      expect(map.getCell(0, 5).cell, isA<WallCell>());

      // Interior cells should be ground
      expect(map.getCell(2, 2).cell, isA<GroundCell>());
      expect(map.getCell(3, 3).cell, isA<GroundCell>());
    });

    test('custom generator overrides default', () {
      final registry = CellRegistry();
      registry.register({
        0: const GroundCell(),
        1: const WallCell(),
        2: const WaterCell(),
      });

      final map = GameMap.standard(
        registry,
        size: 4,
        border: 0,
        generator: (x, y, size, border) => 2,
      );

      expect(map.getCell(0, 0).cell, isA<WaterCell>());
      expect(map.getCell(1, 1).cell, isA<WaterCell>());
      expect(map.getCell(3, 3).cell, isA<WaterCell>());
    });
  });
}
