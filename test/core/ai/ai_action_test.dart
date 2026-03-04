import 'dart:ui';

import 'package:alebel/core/ai/ai_action.dart';
import 'package:alebel/core/ai/simple_ai.dart';
import 'package:alebel/core/map/game_map.dart';
import 'package:alebel/core/skills/skill.dart';
import 'package:alebel/core/unit/unit_state.dart';
import 'package:alebel/models/cells/cell_registry.dart';
import 'package:alebel/models/cells/cell_base.dart';
import 'package:alebel/models/units/basic_soldier.dart';
import 'package:alebel/models/units/unit_base.dart';
import 'package:flutter_test/flutter_test.dart';

UnitState _makeUnit({
  required int x,
  required int y,
  UnitFaction faction = UnitFaction.player,
  int attackRange = 1,
  int speed = 10,
}) {
  final unit = BasicSoldier(
    color: const Color(0xFF0000FF),
    faction: faction,
    attackRange: attackRange,
    speed: speed,
  );
  return UnitState(unit: unit, x: x, y: y);
}

GameMap _makeMap(int size) {
  final registry = CellRegistry();
  registry.register({0: const GroundCell(), 1: const WallCell()});
  final matrix = List.generate(size, (_) => List.generate(size, (_) => 0));
  return GameMap.fromMatrix(matrix, registry);
}

void main() {
  group('AggressiveAI with isHostileTo', () {
    test('enemy AI targets player units', () {
      final ai = const AggressiveAI();
      final enemy = _makeUnit(x: 5, y: 5, faction: UnitFaction.enemy);
      final player = _makeUnit(x: 6, y: 5, faction: UnitFaction.player);

      final map = _makeMap(10);
      final ctx = AIContext(
        gameMap: map,
        units: [enemy, player],
        getUnitAt: (x, y) {
          if (x == enemy.x && y == enemy.y) return enemy;
          if (x == player.x && y == player.y) return player;
          return null;
        },
      );

      final actions = ai.decideTurn(enemy, ctx);
      // Adjacent, should attack
      expect(actions, hasLength(1));
      expect(actions.first, isA<AIUseSkill>());
    });

    test('enemy AI ignores neutral units', () {
      final ai = const AggressiveAI();
      final enemy = _makeUnit(x: 5, y: 5, faction: UnitFaction.enemy);
      final neutral = _makeUnit(x: 6, y: 5, faction: UnitFaction.neutral);

      final map = _makeMap(10);
      final ctx = AIContext(
        gameMap: map,
        units: [enemy, neutral],
        getUnitAt: (x, y) {
          if (x == enemy.x && y == enemy.y) return enemy;
          if (x == neutral.x && y == neutral.y) return neutral;
          return null;
        },
      );

      final actions = ai.decideTurn(enemy, ctx);
      // Neutral is not hostile, should have no actions
      expect(actions, isEmpty);
    });

    test('enemy AI ignores ally units (ally to enemy is hostile but ally is an allied faction)', () {
      final ai = const AggressiveAI();
      // enemy unit should attack ally units because they are hostile
      final enemy = _makeUnit(x: 5, y: 5, faction: UnitFaction.enemy);
      final ally = _makeUnit(x: 6, y: 5, faction: UnitFaction.ally);

      final map = _makeMap(10);
      final ctx = AIContext(
        gameMap: map,
        units: [enemy, ally],
        getUnitAt: (x, y) {
          if (x == enemy.x && y == enemy.y) return enemy;
          if (x == ally.x && y == ally.y) return ally;
          return null;
        },
      );

      final actions = ai.decideTurn(enemy, ctx);
      // ally is hostile to enemy, so should attack
      expect(actions, hasLength(1));
      expect(actions.first, isA<AIUseSkill>());
    });

    test('AI generates AIUseSkill with AttackSkill', () {
      final ai = const AggressiveAI();
      final enemy = _makeUnit(x: 5, y: 5, faction: UnitFaction.enemy);
      final player = _makeUnit(x: 6, y: 5, faction: UnitFaction.player);

      final map = _makeMap(10);
      final ctx = AIContext(
        gameMap: map,
        units: [enemy, player],
        getUnitAt: (x, y) {
          if (x == enemy.x && y == enemy.y) return enemy;
          if (x == player.x && y == player.y) return player;
          return null;
        },
      );

      final actions = ai.decideTurn(enemy, ctx);
      expect(actions.first, isA<AIUseSkill>());
      final useSkill = actions.first as AIUseSkill;
      expect(useSkill.skill, isA<AttackSkill>());
      expect(useSkill.target, equals((x: player.x, y: player.y)));
    });

    test('AI moves then attacks when out of range', () {
      final ai = const AggressiveAI();
      final enemy = _makeUnit(x: 2, y: 2, faction: UnitFaction.enemy);
      final player = _makeUnit(x: 8, y: 2, faction: UnitFaction.player);

      final map = _makeMap(10);
      final ctx = AIContext(
        gameMap: map,
        units: [enemy, player],
        getUnitAt: (x, y) {
          if (x == enemy.x && y == enemy.y) return enemy;
          if (x == player.x && y == player.y) return player;
          return null;
        },
      );

      final actions = ai.decideTurn(enemy, ctx);
      // Should have a move action (and possibly attack if close enough after move)
      expect(actions.isNotEmpty, isTrue);
      expect(actions.first, isA<AIMove>());
    });
  });

  group('AIUseSkill canUse check', () {
    test('respects maxUsesPerTurn', () {
      final unit = _makeUnit(x: 0, y: 0, faction: UnitFaction.enemy);
      final skill = AttackSkill();

      // Simulate one use this turn
      unit.beginTurnRecord();
      unit.recordSkill(skill);

      // maxUsesPerTurn = 1, so canUse should be false
      expect(unit.canUse(skill), isFalse);
    });
  });
}
