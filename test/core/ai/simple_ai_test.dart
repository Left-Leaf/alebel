import 'dart:ui';

import 'package:alebel/core/map/board.dart';
import 'package:alebel/core/unit/unit_state.dart';
import 'package:alebel/models/units/basic_soldier.dart';
import 'package:alebel/models/units/unit_base.dart';
import 'package:flutter_test/flutter_test.dart';

UnitState _makeUnit({
  required int x,
  required int y,
  UnitFaction faction = UnitFaction.player,
  int attackRange = 1,
}) {
  final unit = BasicSoldier(
    color: const Color(0xFF0000FF),
    faction: faction,
    attackRange: attackRange,
  );
  return UnitState(unit: unit, x: x, y: y);
}

int _manhattan(Position a, Position b) {
  return (a.x - b.x).abs() + (a.y - b.y).abs();
}

void main() {
  group('AI targeting logic', () {
    test('manhattan distance calculation', () {
      expect(_manhattan((x: 0, y: 0), (x: 3, y: 4)), equals(7));
      expect(_manhattan((x: 5, y: 5), (x: 5, y: 5)), equals(0));
      expect(_manhattan((x: 1, y: 1), (x: 4, y: 1)), equals(3));
    });

    test('finds nearest player unit', () {
      final enemy = _makeUnit(x: 5, y: 5, faction: UnitFaction.enemy);
      final nearPlayer = _makeUnit(x: 6, y: 5, faction: UnitFaction.player);
      final farPlayer = _makeUnit(x: 10, y: 10, faction: UnitFaction.player);

      final players = [nearPlayer, farPlayer];
      // Simulate AI nearest-enemy finding
      UnitState? nearest;
      int minDist = 999999;
      for (final p in players) {
        final dist = _manhattan((x: enemy.x, y: enemy.y), (x: p.x, y: p.y));
        if (dist < minDist) {
          minDist = dist;
          nearest = p;
        }
      }

      expect(nearest, equals(nearPlayer));
      expect(minDist, equals(1));
    });

    test('attack range check', () {
      final attacker = _makeUnit(x: 5, y: 5, faction: UnitFaction.enemy, attackRange: 1);
      final adjacent = _makeUnit(x: 6, y: 5);
      final far = _makeUnit(x: 8, y: 5);

      final distAdj = _manhattan(
        (x: attacker.x, y: attacker.y),
        (x: adjacent.x, y: adjacent.y),
      );
      final distFar = _manhattan(
        (x: attacker.x, y: attacker.y),
        (x: far.x, y: far.y),
      );

      expect(distAdj <= attacker.unit.attackRange, isTrue);
      expect(distFar <= attacker.unit.attackRange, isFalse);
    });

    test('pathfinding finds best approach position', () {
      // Test that BFS pathfinding can find positions closer to target
      final board = _TestBoard(width: 10, height: 10);
      final targetPos = (x: 8, y: 5);

      final paths = board.getMovablePositions((x: 5, y: 5), 3);
      final endpoints = <Position>{};
      for (final (path, _) in paths) {
        endpoints.add(path.last);
      }

      // Find endpoint closest to target
      Position? bestEnd;
      int bestDist = 999999;
      for (final end in endpoints) {
        final dist = _manhattan(end, targetPos);
        if (dist < bestDist) {
          bestDist = dist;
          bestEnd = end;
        }
      }

      expect(bestEnd, isNotNull);
      // Should be closer to target than start
      expect(bestDist, lessThan(_manhattan((x: 5, y: 5), targetPos)));
    });
  });
}

class _TestBoard implements BoardImpl {
  @override
  final int width;
  @override
  final int height;

  _TestBoard({required this.width, required this.height});

  @override
  bool blocksPass(int x, int y) => false;
  @override
  bool blocksVision(int x, int y) => false;
  @override
  bool canStand(int x, int y) => true;
  @override
  bool isCellKnown(int x, int y) => true;
}
