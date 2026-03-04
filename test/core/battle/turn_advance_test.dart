import 'dart:ui';

import 'package:alebel/common/constants.dart';
import 'package:alebel/core/battle/turn_delegate.dart';
import 'package:alebel/core/battle/turn_manager.dart';
import 'package:alebel/core/unit/unit_state.dart';
import 'package:alebel/models/units/basic_soldier.dart';
import 'package:alebel/models/units/unit_base.dart';
import 'package:flutter_test/flutter_test.dart';

UnitState _makeUnit({
  int speed = 10,
  int maxHp = 100,
  UnitFaction faction = UnitFaction.player,
}) {
  final unit = BasicSoldier(
    color: const Color(0xFF0000FF),
    faction: faction,
    speed: speed,
    maxHp: maxHp,
  );
  return UnitState(unit: unit, x: 0, y: 0);
}

/// Delegate that kills units during onBuffTurnStart to test iterative advance.
class _KillingDelegate implements TurnDelegate {
  final Set<UnitState> unitsToKill;
  final TurnManager tm;
  final List<String> log = [];

  _KillingDelegate({required this.unitsToKill, required this.tm});

  @override
  Future<void> onTurnStart(UnitState unit) async {
    log.add('turnStart:${unit.hashCode}');
  }

  @override
  Future<void> onTurnEnd(UnitState unit) async {
    log.add('turnEnd:${unit.hashCode}');
  }

  @override
  Future<void> onBuffTurnStart(UnitState unit) async {
    log.add('buffStart:${unit.hashCode}');
    if (unitsToKill.contains(unit)) {
      // Simulate lethal poison damage
      unit.takeDamage(unit.maxHp);
    }
  }

  @override
  Future<void> onBuffTurnEnd(UnitState unit) async {
    log.add('buffEnd:${unit.hashCode}');
  }

  @override
  Future<void> onCellTurnStart(UnitState unit) async {
    log.add('cellStart:${unit.hashCode}');
  }

  @override
  Future<void> onUnitDeath(UnitState unit) async {
    log.add('death:${unit.hashCode}');
    await tm.removeUnit(unit);
  }
}

/// Simple delegate that just records turn starts.
class _RecordingDelegate implements TurnDelegate {
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
  group('TurnManager iterative advance', () {
    test('skips unit killed by buff and advances to next', () async {
      final tm = TurnManager();
      final u1 = _makeUnit(speed: 20, maxHp: 50);
      final u2 = _makeUnit(speed: 10, maxHp: 100);

      tm.registerUnit(u1);
      tm.registerUnit(u2);
      u1.actionGauge = 0;
      u2.actionGauge = 0;

      // u1 will die from buff, u2 should get the turn
      final delegate = _KillingDelegate(unitsToKill: {u1}, tm: tm);
      tm.delegate = delegate;

      await tm.startBattle();

      // u1 was fastest, got picked first, died from buff, then u2 got the turn
      expect(delegate.log, contains('buffStart:${u1.hashCode}'));
      expect(delegate.log, contains('death:${u1.hashCode}'));
      expect(delegate.log, contains('turnStart:${u2.hashCode}'));

      // u1 should NOT have received onTurnStart
      expect(delegate.log, isNot(contains('turnStart:${u1.hashCode}')));
    });

    test('handles multiple deaths in sequence without stack overflow', () async {
      final tm = TurnManager();
      // Create 5 units that all die from buff, plus one survivor
      final dying = List.generate(5, (_) => _makeUnit(speed: 20, maxHp: 10));
      final survivor = _makeUnit(speed: 10, maxHp: 100);

      for (final u in dying) {
        tm.registerUnit(u);
        u.actionGauge = GameConstants.maxActionGauge; // All ready to act
      }
      tm.registerUnit(survivor);
      survivor.actionGauge = 0;

      final delegate = _KillingDelegate(unitsToKill: dying.toSet(), tm: tm);
      tm.delegate = delegate;

      // This should NOT stack overflow — iterative loop handles all deaths
      await tm.startBattle();

      // All dying units should have death logged
      for (final u in dying) {
        expect(delegate.log, contains('death:${u.hashCode}'));
      }

      // Survivor should eventually get a turn after tick fills its gauge
      expect(delegate.log, contains('turnStart:${survivor.hashCode}'));
    });

    test('endTurn advances to next unit iteratively', () async {
      final tm = TurnManager();
      final delegate = _RecordingDelegate();
      tm.delegate = delegate;

      final u1 = _makeUnit(speed: 20);
      final u2 = _makeUnit(speed: 10);
      tm.registerUnit(u1);
      tm.registerUnit(u2);
      u1.actionGauge = 0;
      u2.actionGauge = 0;

      await tm.startBattle();
      expect(delegate.turnStartUnits, [u1]);

      // End u1's turn, u2 should eventually get a turn
      await tm.endTurn();
      expect(delegate.turnStartUnits.length, greaterThanOrEqualTo(2));
    });
  });

  group('TurnManager removeUnit during active turn', () {
    test('removing active unit advances to next', () async {
      final tm = TurnManager();
      final delegate = _RecordingDelegate();
      tm.delegate = delegate;

      final u1 = _makeUnit(speed: 20);
      final u2 = _makeUnit(speed: 10);
      tm.registerUnit(u1);
      tm.registerUnit(u2);
      u1.actionGauge = 0;
      u2.actionGauge = 0;

      await tm.startBattle();
      expect(tm.activeUnit, equals(u1));

      // Remove active unit (simulating death)
      await tm.removeUnit(u1);

      // Should advance to u2
      expect(delegate.turnStartUnits.last, equals(u2));
    });
  });
}
