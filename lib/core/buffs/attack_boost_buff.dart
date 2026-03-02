part of 'buff.dart';

class AttackBoostBuff extends Buff {
  final int bonusAttack;

  @override
  String get id => 'attack_boost';

  @override
  String get name => 'Attack Boost';

  @override
  String get description => 'Increases attack by $bonusAttack';

  @override
  int get priority => 10;

  AttackBoostBuff({required this.bonusAttack, required super.duration});

  @override
  void apply(UnitState state) {
    state.currentAttack += bonusAttack;
  }
}
