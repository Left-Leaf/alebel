import 'dart:ui';

import 'package:alebel/common/constants.dart';
import 'package:alebel/core/battle/turn_manager.dart';
import 'package:alebel/core/events/event_bus.dart';
import 'package:alebel/core/events/game_event.dart';
import 'package:alebel/core/unit/unit_state.dart';
import 'package:alebel/models/units/basic_soldier.dart';
import 'package:alebel/models/units/unit_base.dart';
import 'package:flutter_test/flutter_test.dart';

UnitState _makeUnit({int speed = 10, UnitFaction faction = UnitFaction.player}) {
  final unit = BasicSoldier(
    color: const Color(0xFF0000FF),
    faction: faction,
    speed: speed,
  );
  return UnitState(unit: unit, x: 0, y: 0);
}

void main() {
  group('TurnManager', () {
    late TurnManager tm;
    late EventBus eventBus;

    setUp(() {
      eventBus = EventBus();
      tm = TurnManager(eventBus: eventBus);
    });

    test('registerUnit initializes action gauge', () {
      final u = _makeUnit(speed: 10);
      tm.registerUnit(u);
      // 初始化后 gauge 应在 [0, maxActionGauge * 0.5] 范围内
      expect(u.actionGauge, greaterThanOrEqualTo(0));
      expect(u.actionGauge, lessThanOrEqualTo(GameConstants.maxActionGauge * 0.5));
    });

    test('duplicate registerUnit is ignored', () {
      final u = _makeUnit();
      tm.registerUnit(u);
      final initialGauge = u.actionGauge;
      tm.registerUnit(u); // should be no-op
      expect(u.actionGauge, equals(initialGauge));
    });

    test('faster unit acts first', () {
      final slow = _makeUnit(speed: 5);
      final fast = _makeUnit(speed: 20);

      tm.registerUnit(slow);
      tm.registerUnit(fast);

      // Reset gauges to 0 for deterministic test
      slow.actionGauge = 0;
      fast.actionGauge = 0;

      UnitState? firstToAct;
      eventBus.on<TurnStartEvent>().listen((e) {
        firstToAct ??= e.unit;
      });

      tm.startBattle();
      expect(firstToAct, equals(fast));
    });

    test('endTurn resets gauge and recovers AP', () {
      final u1 = _makeUnit(speed: 10);
      final u2 = _makeUnit(speed: 5);
      tm.registerUnit(u1);
      tm.registerUnit(u2);
      u1.actionGauge = 0;
      u2.actionGauge = 0;

      // Track which units got turns
      final turnUnits = <UnitState>[];
      eventBus.on<TurnStartEvent>().listen((e) {
        turnUnits.add(e.unit);
      });

      tm.startBattle();
      // First turn should be the faster unit (u1)
      expect(turnUnits.length, equals(1));
      expect(turnUnits.first, equals(u1));

      // Deplete AP
      u1.currentActionPoints = 0;

      // End u1's turn
      tm.endTurn();

      // After endTurn, u1's AP should be recovered
      expect(u1.currentActionPoints, equals(u1.recoveryActionPoints));
    });

    test('removeUnit removes from tracking', () {
      final u1 = _makeUnit(speed: 10);
      final u2 = _makeUnit(speed: 10);
      tm.registerUnit(u1);
      tm.registerUnit(u2);

      tm.removeUnit(u1);

      // Only u2 should act
      UnitState? acted;
      eventBus.on<TurnStartEvent>().listen((e) {
        acted = e.unit;
      });
      tm.startBattle();
      expect(acted, equals(u2));
    });

    test('getPredictedTurnOrder returns correct count', () {
      final u1 = _makeUnit(speed: 10);
      final u2 = _makeUnit(speed: 15);
      tm.registerUnit(u1);
      tm.registerUnit(u2);
      u1.actionGauge = 0;
      u2.actionGauge = 0;

      // Need to consume turn start to prevent infinite recursion
      eventBus.on<TurnStartEvent>().listen((_) {});
      tm.startBattle();

      final order = tm.getPredictedTurnOrder(5);
      expect(order.length, equals(5));
    });

    test('getPredictedTurnOrder favors faster unit', () {
      final slow = _makeUnit(speed: 5);
      final fast = _makeUnit(speed: 20);
      tm.registerUnit(slow);
      tm.registerUnit(fast);
      slow.actionGauge = 0;
      fast.actionGauge = 0;

      eventBus.on<TurnStartEvent>().listen((_) {});
      tm.startBattle();

      final order = tm.getPredictedTurnOrder(6);
      // In 6 predicted turns, fast should appear more often
      final fastCount = order.where((u) => u == fast).length;
      final slowCount = order.where((u) => u == slow).length;
      expect(fastCount, greaterThan(slowCount));
    });
  });
}
