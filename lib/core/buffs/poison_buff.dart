part of 'buff.dart';

class PoisonBuff extends Buff {
  final int damagePerTurn;

  @override
  String get id => 'poison';

  @override
  String get name => 'Poison';

  @override
  String get description => 'Takes $damagePerTurn damage at the start of each turn';

  PoisonBuff({required this.damagePerTurn, required super.duration});

  @override
  void apply(UnitState state) {
    // Poison does not modify attributes
  }

  @override
  void onTurnStart(UnitState state) {
    state.takeDamage(damagePerTurn);
  }
}
