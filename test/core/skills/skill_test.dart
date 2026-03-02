import 'package:alebel/core/skills/skill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Skill.getPositionsInRange', () {
    test('returns correct positions for range 1', () {
      final positions = Skill.getPositionsInRange(
        (x: 5, y: 5), 1,
        mapWidth: 10, mapHeight: 10,
      );

      // Range 1 from (5,5): 4 adjacent cells
      expect(positions.length, equals(4));

      final expected = {
        (x: 4, y: 5),
        (x: 6, y: 5),
        (x: 5, y: 4),
        (x: 5, y: 6),
      };
      expect(positions.toSet(), equals(expected));
    });

    test('returns correct positions for range 2', () {
      final positions = Skill.getPositionsInRange(
        (x: 5, y: 5), 2,
        mapWidth: 10, mapHeight: 10,
      );

      // Range 2: 4 + 8 = 12 positions (manhattan distance <= 2, excluding center)
      expect(positions.length, equals(12));
    });

    test('excludes center', () {
      final positions = Skill.getPositionsInRange(
        (x: 5, y: 5), 3,
        mapWidth: 10, mapHeight: 10,
      );

      expect(positions.contains((x: 5, y: 5)), isFalse);
    });

    test('clips to map boundaries', () {
      final positions = Skill.getPositionsInRange(
        (x: 0, y: 0), 2,
        mapWidth: 10, mapHeight: 10,
      );

      // All positions should be within bounds
      for (final pos in positions) {
        expect(pos.x, greaterThanOrEqualTo(0));
        expect(pos.y, greaterThanOrEqualTo(0));
        expect(pos.x, lessThan(10));
        expect(pos.y, lessThan(10));
      }

      // From (0,0) range 2: should be fewer than full diamond
      // Full range 2 diamond (excluding center) = 12
      // Clipped at corner = only positions in quadrant 1
      // (1,0), (2,0), (0,1), (1,1), (0,2) = 5
      expect(positions.length, equals(5));
    });

    test('range 0 returns empty list', () {
      final positions = Skill.getPositionsInRange(
        (x: 5, y: 5), 0,
        mapWidth: 10, mapHeight: 10,
      );

      // Range 0 means only center, which is excluded
      expect(positions.isEmpty, isTrue);
    });

    test('all positions respect manhattan distance', () {
      const center = (x: 5, y: 5);
      const range = 3;
      final positions = Skill.getPositionsInRange(
        center, range,
        mapWidth: 20, mapHeight: 20,
      );

      for (final pos in positions) {
        final distance = (pos.x - center.x).abs() + (pos.y - center.y).abs();
        expect(distance, lessThanOrEqualTo(range));
        expect(distance, greaterThan(0));
      }
    });
  });
}
