import 'dart:ui';

import 'package:alebel/core/unit/unit_state.dart';
import 'package:alebel/models/units/basic_soldier.dart';
import 'package:alebel/models/units/unit_base.dart';
import 'package:flutter_test/flutter_test.dart';

UnitState _makeUnit({
  int maxHp = 100,
  int attack = 10,
  int speed = 10,
  int moveRange = 5,
}) {
  final unit = BasicSoldier(
    color: const Color(0xFF0000FF),
    faction: UnitFaction.player,
    maxHp: maxHp,
    attack: attack,
    speed: speed,
    moveRange: moveRange,
  );
  return UnitState(unit: unit, x: 0, y: 0);
}

void main() {
  group('HealthMixin (via UnitState)', () {
    test('takeDamage reduces HP', () {
      final u = _makeUnit(maxHp: 100);
      final actual = u.takeDamage(30);
      expect(actual, equals(30));
      expect(u.currentHp, equals(70));
    });

    test('takeDamage cannot go below 0', () {
      final u = _makeUnit(maxHp: 50);
      final actual = u.takeDamage(80);
      expect(actual, equals(50));
      expect(u.currentHp, equals(0));
      expect(u.isDead, isTrue);
    });

    test('takeDamage with 0 amount does nothing', () {
      final u = _makeUnit(maxHp: 100);
      final actual = u.takeDamage(0);
      expect(actual, equals(0));
      expect(u.currentHp, equals(100));
    });

    test('isDead after lethal damage', () {
      final u = _makeUnit(maxHp: 10);
      u.takeDamage(10);
      expect(u.isDead, isTrue);
      expect(u.isAlive, isFalse);
    });

    test('heal restores HP', () {
      final u = _makeUnit(maxHp: 100);
      u.takeDamage(50);
      final healed = u.heal(30);
      expect(healed, equals(30));
      expect(u.currentHp, equals(80));
    });

    test('heal cannot exceed maxHp', () {
      final u = _makeUnit(maxHp: 100);
      u.takeDamage(10);
      final healed = u.heal(50);
      expect(healed, equals(10));
      expect(u.currentHp, equals(100));
    });

    test('heal on dead unit does nothing', () {
      final u = _makeUnit(maxHp: 10);
      u.takeDamage(10);
      expect(u.isDead, isTrue);
      final healed = u.heal(50);
      expect(healed, equals(0));
      expect(u.currentHp, equals(0));
    });
  });

  group('ActionPointMixin (via UnitState)', () {
    test('spendAp deducts correctly', () {
      final u = _makeUnit(moveRange: 5);
      final spent = u.spendAp(3);
      expect(spent, equals(3));
      expect(u.currentActionPoints, equals(2));
    });

    test('spendAp clamps to available', () {
      final u = _makeUnit(moveRange: 3);
      final spent = u.spendAp(10);
      expect(spent, equals(3));
      expect(u.currentActionPoints, equals(0));
    });

    test('recoverAp restores to recovery amount', () {
      final u = _makeUnit(moveRange: 5);
      u.currentActionPoints = 0;
      u.recoverAp();
      expect(u.currentActionPoints, equals(5));
    });

    test('hasAp returns false when 0', () {
      final u = _makeUnit(moveRange: 5);
      u.currentActionPoints = 0;
      expect(u.hasAp, isFalse);
    });
  });

  group('recalculateAttributes', () {
    test('resets to base values', () {
      final u = _makeUnit(maxHp: 100, attack: 10, speed: 10, moveRange: 5);
      u.currentAttack = 999;
      u.currentSpeed = 999;
      u.recalculateAttributes();
      expect(u.currentAttack, equals(10));
      expect(u.currentSpeed, equals(10));
      expect(u.maxActionPoints, equals(5));
    });
  });
}
