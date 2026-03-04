import '../battle/battle_api.dart';
import '../unit/unit_state.dart';
import 'buff.dart';

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
  Future<void> onTurnStart(UnitState state, {BattleAPI? api}) async {
    if (api != null) {
      await api.damageUnit(state, damagePerTurn);
    } else {
      state.takeDamage(damagePerTurn);
    }
  }
}
