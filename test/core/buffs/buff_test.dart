import 'dart:ui';

import 'package:alebel/core/buffs/buff.dart';
import 'package:alebel/core/unit/unit_state.dart';
import 'package:alebel/models/units/basic_soldier.dart';
import 'package:alebel/models/units/unit_base.dart';
import 'package:flutter_test/flutter_test.dart';

UnitState _makeUnit({
  int maxHp = 100,
  int attack = 10,
  int speed = 10,
}) {
  final unit = BasicSoldier(
    color: const Color(0xFF0000FF),
    faction: UnitFaction.player,
    maxHp: maxHp,
    attack: attack,
    speed: speed,
  );
  return UnitState(unit: unit, x: 0, y: 0);
}

void main() {
  group('PoisonBuff', () {
    test('deals damage on turn start', () async {
      final u = _makeUnit(maxHp: 100);
      final poison = PoisonBuff(damagePerTurn: 15, duration: 3);

      u.addBuff(poison);
      await poison.onTurnStart(u);

      expect(u.currentHp, equals(85));
    });

    test('can kill unit over multiple turns', () async {
      final u = _makeUnit(maxHp: 30);
      final poison = PoisonBuff(damagePerTurn: 15, duration: 5);
      u.addBuff(poison);

      await poison.onTurnStart(u); // 30 - 15 = 15
      expect(u.currentHp, equals(15));
      expect(u.isDead, isFalse);

      await poison.onTurnStart(u); // 15 - 15 = 0
      expect(u.currentHp, equals(0));
      expect(u.isDead, isTrue);
    });

    test('does not modify attributes', () {
      final u = _makeUnit(attack: 10, speed: 10);
      final poison = PoisonBuff(damagePerTurn: 5, duration: 3);

      u.addBuff(poison);
      // apply is called via addBuff -> recalculateAttributes
      expect(u.currentAttack, equals(10));
      expect(u.currentSpeed, equals(10));
    });

    test('expires after duration', () async {
      final u = _makeUnit();
      final poison = PoisonBuff(damagePerTurn: 5, duration: 2);
      u.addBuff(poison);

      expect(await poison.onTurnEnd(u), isFalse); // duration 2 -> 1
      expect(await poison.onTurnEnd(u), isTrue); // duration 1 -> 0, expired
    });
  });

  group('AttackBoostBuff', () {
    test('increases attack via apply', () {
      final u = _makeUnit(attack: 10);
      final boost = AttackBoostBuff(bonusAttack: 5, duration: 3);

      u.addBuff(boost);
      expect(u.currentAttack, equals(15));
    });

    test('attack reverts after removal', () {
      final u = _makeUnit(attack: 10);
      final boost = AttackBoostBuff(bonusAttack: 5, duration: 3);

      u.addBuff(boost);
      expect(u.currentAttack, equals(15));

      u.removeBuff(boost);
      expect(u.currentAttack, equals(10));
    });

    test('expires after duration', () async {
      final u = _makeUnit();
      final boost = AttackBoostBuff(bonusAttack: 5, duration: 1);
      u.addBuff(boost);

      expect(await boost.onTurnEnd(u), isTrue); // duration 1 -> 0
    });
  });

  group('SpeedDebuffBuff', () {
    test('reduces speed via apply', () {
      final u = _makeUnit(speed: 10);
      final debuff = SpeedDebuffBuff(speedReduction: 3, duration: 2);

      u.addBuff(debuff);
      expect(u.currentSpeed, equals(7));
    });

    test('speed clamps to 0', () {
      final u = _makeUnit(speed: 5);
      final debuff = SpeedDebuffBuff(speedReduction: 10, duration: 2);

      u.addBuff(debuff);
      expect(u.currentSpeed, equals(0));
    });

    test('speed reverts after removal', () {
      final u = _makeUnit(speed: 10);
      final debuff = SpeedDebuffBuff(speedReduction: 3, duration: 2);

      u.addBuff(debuff);
      expect(u.currentSpeed, equals(7));

      u.removeBuff(debuff);
      expect(u.currentSpeed, equals(10));
    });

    test('expires after duration', () async {
      final u = _makeUnit();
      final debuff = SpeedDebuffBuff(speedReduction: 3, duration: 2);
      u.addBuff(debuff);

      expect(await debuff.onTurnEnd(u), isFalse); // 2 -> 1
      expect(await debuff.onTurnEnd(u), isTrue); // 1 -> 0
    });
  });
}
