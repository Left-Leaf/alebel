import 'package:alebel/models/units/unit_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnitFaction.isHostileTo', () {
    test('player is hostile to enemy', () {
      expect(UnitFaction.player.isHostileTo(UnitFaction.enemy), isTrue);
    });

    test('enemy is hostile to player', () {
      expect(UnitFaction.enemy.isHostileTo(UnitFaction.player), isTrue);
    });

    test('ally is hostile to enemy', () {
      expect(UnitFaction.ally.isHostileTo(UnitFaction.enemy), isTrue);
    });

    test('enemy is hostile to ally', () {
      expect(UnitFaction.enemy.isHostileTo(UnitFaction.ally), isTrue);
    });

    test('player is not hostile to ally', () {
      expect(UnitFaction.player.isHostileTo(UnitFaction.ally), isFalse);
    });

    test('ally is not hostile to player', () {
      expect(UnitFaction.ally.isHostileTo(UnitFaction.player), isFalse);
    });

    test('player is not hostile to neutral', () {
      expect(UnitFaction.player.isHostileTo(UnitFaction.neutral), isFalse);
    });

    test('neutral is not hostile to anyone', () {
      expect(UnitFaction.neutral.isHostileTo(UnitFaction.player), isFalse);
      expect(UnitFaction.neutral.isHostileTo(UnitFaction.enemy), isFalse);
      expect(UnitFaction.neutral.isHostileTo(UnitFaction.ally), isFalse);
      expect(UnitFaction.neutral.isHostileTo(UnitFaction.neutral), isFalse);
    });

    test('same faction is never hostile', () {
      for (final f in UnitFaction.values) {
        expect(f.isHostileTo(f), isFalse);
      }
    });
  });
}
