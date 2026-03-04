import 'dart:ui';

import 'package:alebel/core/battle/battle_api.dart';
import 'package:alebel/core/map/board.dart';
import 'package:alebel/core/skills/skill.dart';
import 'package:alebel/core/unit/unit_state.dart';
import 'package:alebel/models/units/basic_soldier.dart';
import 'package:alebel/models/units/unit_base.dart';
import 'package:flutter_test/flutter_test.dart';

UnitState _makeUnit({int moveRange = 5}) {
  final unit = BasicSoldier(
    color: const Color(0xFF0000FF),
    faction: UnitFaction.player,
    moveRange: moveRange,
  );
  return UnitState(unit: unit, x: 0, y: 0);
}

/// 用于测试冷却和消耗的自定义技能
class _CooldownSkill extends Skill {
  @override
  String get name => 'CooldownSkill';

  @override
  int get cooldown => 2;

  @override
  List<({Position pos, Color color})> getHighlightPositions(
    UnitState state,
    SkillContext ctx,
  ) => [];

  @override
  Future<bool> onTap(UnitState state, Position target, BattleAPI api) async =>
      true;
}

class _CostSkill extends Skill {
  @override
  String get name => 'CostSkill';

  @override
  int get cost => 3;

  @override
  List<({Position pos, Color color})> getHighlightPositions(
    UnitState state,
    SkillContext ctx,
  ) => [];

  @override
  Future<bool> onTap(UnitState state, Position target, BattleAPI api) async =>
      true;
}

class _LimitedSkill extends Skill {
  @override
  String get name => 'LimitedSkill';

  @override
  int get maxUsesPerTurn => 2;

  @override
  List<({Position pos, Color color})> getHighlightPositions(
    UnitState state,
    SkillContext ctx,
  ) => [];

  @override
  Future<bool> onTap(UnitState state, Position target, BattleAPI api) async =>
      true;
}

void main() {
  group('SkillRecordMixin', () {
    group('usesThisTurn', () {
      test('returns 0 before any turn begins', () {
        final u = _makeUnit();
        final skill = AttackSkill();
        expect(u.usesThisTurn(skill), equals(0));
      });

      test('counts skills used this turn', () {
        final u = _makeUnit();
        final skill = AttackSkill();
        u.beginTurnRecord();
        u.recordSkill(skill);
        u.recordSkill(skill);
        expect(u.usesThisTurn(skill), equals(2));
      });

      test('only counts current turn', () {
        final u = _makeUnit();
        final skill = AttackSkill();
        u.beginTurnRecord();
        u.recordSkill(skill);
        u.recordSkill(skill);
        u.beginTurnRecord(); // new turn
        u.recordSkill(skill);
        expect(u.usesThisTurn(skill), equals(1));
      });

      test('distinguishes different skill instances', () {
        final u = _makeUnit();
        final attack = AttackSkill();
        final move = MoveSkill();
        u.beginTurnRecord();
        u.recordSkill(attack);
        u.recordSkill(move);
        expect(u.usesThisTurn(attack), equals(1));
        expect(u.usesThisTurn(move), equals(1));
      });
    });

    group('lastUsedTurnIndex', () {
      test('returns null when never used', () {
        final u = _makeUnit();
        final skill = AttackSkill();
        u.beginTurnRecord();
        expect(u.lastUsedTurnIndex(skill), isNull);
      });

      test('returns correct turn index', () {
        final u = _makeUnit();
        final skill = AttackSkill();
        u.beginTurnRecord(); // turn 0
        u.recordSkill(skill);
        u.beginTurnRecord(); // turn 1
        u.beginTurnRecord(); // turn 2
        expect(u.lastUsedTurnIndex(skill), equals(0));
      });

      test('returns latest turn index', () {
        final u = _makeUnit();
        final skill = AttackSkill();
        u.beginTurnRecord(); // turn 0
        u.recordSkill(skill);
        u.beginTurnRecord(); // turn 1
        u.beginTurnRecord(); // turn 2
        u.recordSkill(skill);
        expect(u.lastUsedTurnIndex(skill), equals(2));
      });
    });

    group('remainingCooldown', () {
      test('returns 0 for skill with no cooldown', () {
        final u = _makeUnit();
        final skill = AttackSkill(); // cooldown = 0
        u.beginTurnRecord();
        u.recordSkill(skill);
        expect(u.remainingCooldown(skill), equals(0));
      });

      test('returns 0 when never used', () {
        final u = _makeUnit();
        final skill = _CooldownSkill(); // cooldown = 2
        u.beginTurnRecord();
        expect(u.remainingCooldown(skill), equals(0));
      });

      test('returns full cooldown when just used', () {
        final u = _makeUnit();
        final skill = _CooldownSkill(); // cooldown = 2
        u.beginTurnRecord(); // turn 0
        u.recordSkill(skill);
        // currentTurnIndex = 0, lastUsed = 0 → remaining = max(0, 2 - 0) = 2
        expect(u.remainingCooldown(skill), equals(2));
      });

      test('decreases each turn', () {
        final u = _makeUnit();
        final skill = _CooldownSkill(); // cooldown = 2
        u.beginTurnRecord(); // turn 0
        u.recordSkill(skill);
        u.beginTurnRecord(); // turn 1
        // currentTurnIndex = 1, lastUsed = 0 → remaining = max(0, 2 - 1) = 1
        expect(u.remainingCooldown(skill), equals(1));
      });

      test('returns 0 when cooldown expires', () {
        final u = _makeUnit();
        final skill = _CooldownSkill(); // cooldown = 2
        u.beginTurnRecord(); // turn 0
        u.recordSkill(skill);
        u.beginTurnRecord(); // turn 1
        u.beginTurnRecord(); // turn 2
        // currentTurnIndex = 2, lastUsed = 0 → remaining = max(0, 2 - 2) = 0
        expect(u.remainingCooldown(skill), equals(0));
      });

      test('returns 0 well past cooldown', () {
        final u = _makeUnit();
        final skill = _CooldownSkill(); // cooldown = 2
        u.beginTurnRecord(); // turn 0
        u.recordSkill(skill);
        u.beginTurnRecord(); // turn 1
        u.beginTurnRecord(); // turn 2
        u.beginTurnRecord(); // turn 3
        expect(u.remainingCooldown(skill), equals(0));
      });
    });
  });

  group('UnitState.canUse', () {
    test('returns true for default skill (no restrictions)', () {
      final u = _makeUnit();
      final skill = MoveSkill();
      u.beginTurnRecord();
      expect(u.canUse(skill), isTrue);
    });

    test('returns false when AP insufficient for cost', () {
      final u = _makeUnit(moveRange: 5);
      final skill = _CostSkill(); // cost = 3
      u.beginTurnRecord();
      u.currentActionPoints = 2;
      expect(u.canUse(skill), isFalse);
    });

    test('returns true when AP sufficient for cost', () {
      final u = _makeUnit(moveRange: 5);
      final skill = _CostSkill(); // cost = 3
      u.beginTurnRecord();
      u.currentActionPoints = 3;
      expect(u.canUse(skill), isTrue);
    });

    test('returns false when on cooldown', () {
      final u = _makeUnit();
      final skill = _CooldownSkill(); // cooldown = 2
      u.beginTurnRecord(); // turn 0
      u.recordSkill(skill);
      u.beginTurnRecord(); // turn 1
      expect(u.canUse(skill), isFalse);
    });

    test('returns true when cooldown expired', () {
      final u = _makeUnit();
      final skill = _CooldownSkill(); // cooldown = 2
      u.beginTurnRecord(); // turn 0
      u.recordSkill(skill);
      u.beginTurnRecord(); // turn 1
      u.beginTurnRecord(); // turn 2
      expect(u.canUse(skill), isTrue);
    });

    test('returns false when max uses per turn reached', () {
      final u = _makeUnit();
      final skill = _LimitedSkill(); // maxUsesPerTurn = 2
      u.beginTurnRecord();
      u.recordSkill(skill);
      u.recordSkill(skill);
      expect(u.canUse(skill), isFalse);
    });

    test('returns true when under max uses per turn', () {
      final u = _makeUnit();
      final skill = _LimitedSkill(); // maxUsesPerTurn = 2
      u.beginTurnRecord();
      u.recordSkill(skill);
      expect(u.canUse(skill), isTrue);
    });

    test('AttackSkill limited to 1 use per turn', () {
      final u = _makeUnit();
      final attack = AttackSkill();
      u.beginTurnRecord();
      expect(u.canUse(attack), isTrue);
      u.recordSkill(attack);
      expect(u.canUse(attack), isFalse);
    });

    test('MoveSkill limited to 1 use per turn', () {
      final u = _makeUnit();
      final move = MoveSkill();
      u.beginTurnRecord();
      expect(u.canUse(move), isTrue);
      u.recordSkill(move);
      expect(u.canUse(move), isFalse);
    });

    test('max uses reset on new turn', () {
      final u = _makeUnit();
      final attack = AttackSkill();
      u.beginTurnRecord();
      u.recordSkill(attack);
      expect(u.canUse(attack), isFalse);
      u.beginTurnRecord(); // new turn
      expect(u.canUse(attack), isTrue);
    });
  });
}
