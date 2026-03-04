import 'dart:ui';

import 'package:alebel/common/constants.dart';
import 'package:alebel/core/battle/turn_delegate.dart';
import 'package:alebel/core/battle/turn_manager.dart';
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

class _TestTurnDelegate implements TurnDelegate {
  final List<UnitState> turnStartUnits = [];

  @override
  Future<void> onTurnStart(UnitState unit) async {
    turnStartUnits.add(unit);
  }

  @override
  Future<void> onTurnEnd(UnitState unit) async {}

  @override
  Future<void> onBuffTurnStart(UnitState unit) async {}

  @override
  Future<void> onBuffTurnEnd(UnitState unit) async {}

  @override
  Future<void> onCellTurnStart(UnitState unit) async {}

  @override
  Future<void> onUnitDeath(UnitState unit) async {}
}

void main() {
  group('TurnManager', () {
    late TurnManager tm;
    late _TestTurnDelegate delegate;

    setUp(() {
      tm = TurnManager();
      delegate = _TestTurnDelegate();
      tm.delegate = delegate;
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

    test('faster unit acts first', () async {
      final slow = _makeUnit(speed: 5);
      final fast = _makeUnit(speed: 20);

      tm.registerUnit(slow);
      tm.registerUnit(fast);

      // Reset gauges to 0 for deterministic test
      slow.actionGauge = 0;
      fast.actionGauge = 0;

      await tm.startBattle();
      expect(delegate.turnStartUnits.first, equals(fast));
    });

    test('endTurn resets gauge and recovers AP', () async {
      final u1 = _makeUnit(speed: 10);
      final u2 = _makeUnit(speed: 5);
      tm.registerUnit(u1);
      tm.registerUnit(u2);
      u1.actionGauge = 0;
      u2.actionGauge = 0;

      await tm.startBattle();
      // First turn should be the faster unit (u1)
      expect(delegate.turnStartUnits.length, equals(1));
      expect(delegate.turnStartUnits.first, equals(u1));

      // Deplete AP
      u1.currentActionPoints = 0;

      // End u1's turn
      await tm.endTurn();

      // After endTurn, u1's AP should be recovered
      expect(u1.currentActionPoints, equals(u1.recoveryActionPoints));
    });

    test('removeUnit removes from tracking', () async {
      final u1 = _makeUnit(speed: 10);
      final u2 = _makeUnit(speed: 10);
      tm.registerUnit(u1);
      tm.registerUnit(u2);

      await tm.removeUnit(u1);

      // Only u2 should act
      delegate.turnStartUnits.clear();
      await tm.startBattle();
      expect(delegate.turnStartUnits.length, equals(1));
      expect(delegate.turnStartUnits.first, equals(u2));
    });

    test('getPredictedTurnOrder returns correct count', () async {
      final u1 = _makeUnit(speed: 10);
      final u2 = _makeUnit(speed: 15);
      tm.registerUnit(u1);
      tm.registerUnit(u2);
      u1.actionGauge = 0;
      u2.actionGauge = 0;

      await tm.startBattle();

      final order = tm.getPredictedTurnOrder(5);
      expect(order.length, equals(5));
    });

    test('getPredictedTurnOrder favors faster unit', () async {
      final slow = _makeUnit(speed: 5);
      final fast = _makeUnit(speed: 20);
      tm.registerUnit(slow);
      tm.registerUnit(fast);
      slow.actionGauge = 0;
      fast.actionGauge = 0;

      await tm.startBattle();

      final order = tm.getPredictedTurnOrder(6);
      // In 6 predicted turns, fast should appear more often
      final fastCount = order.where((u) => u == fast).length;
      final slowCount = order.where((u) => u == slow).length;
      expect(fastCount, greaterThan(slowCount));
    });
  });
}
