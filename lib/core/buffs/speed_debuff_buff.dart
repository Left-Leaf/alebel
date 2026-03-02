part of 'buff.dart';

class SpeedDebuffBuff extends Buff {
  final int speedReduction;

  @override
  String get id => 'speed_debuff';

  @override
  String get name => 'Speed Debuff';

  @override
  String get description => 'Reduces speed by $speedReduction';

  @override
  int get priority => 10;

  SpeedDebuffBuff({required this.speedReduction, required super.duration});

  @override
  void apply(UnitState state) {
    state.currentSpeed = (state.currentSpeed - speedReduction).clamp(0, state.currentSpeed);
  }
}
