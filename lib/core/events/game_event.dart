import '../unit/unit_state.dart';

sealed class GameEvent {}

class UnitDamagedEvent extends GameEvent {
  final UnitState unit;
  final int damage;

  UnitDamagedEvent({required this.unit, required this.damage});
}

class UnitDeathEvent extends GameEvent {
  final UnitState unit;

  UnitDeathEvent({required this.unit});
}

class TurnStartEvent extends GameEvent {
  final UnitState unit;

  TurnStartEvent({required this.unit});
}

class TurnEndEvent extends GameEvent {
  final UnitState unit;

  TurnEndEvent({required this.unit});
}

class UnitMovedEvent extends GameEvent {
  final UnitState unit;
  final int fromX;
  final int fromY;
  final int toX;
  final int toY;

  UnitMovedEvent({
    required this.unit,
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
  });
}

class BattleEndEvent extends GameEvent {
  final bool playerWon;

  BattleEndEvent({required this.playerWon});
}
