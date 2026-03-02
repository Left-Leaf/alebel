import '../buffs/buff.dart';
import '../skills/skill.dart';
import '../unit/unit_state.dart';

sealed class GameEvent {}

class UnitDamagedEvent extends GameEvent {
  final UnitState unit;
  final int damage;

  UnitDamagedEvent({required this.unit, required this.damage});
}

class UnitHealedEvent extends GameEvent {
  final UnitState unit;
  final int amount;

  UnitHealedEvent({required this.unit, required this.amount});
}

class UnitDeathEvent extends GameEvent {
  final UnitState unit;

  UnitDeathEvent({required this.unit});
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

class BuffAppliedEvent extends GameEvent {
  final UnitState unit;
  final Buff buff;

  BuffAppliedEvent({required this.unit, required this.buff});
}

class BuffRemovedEvent extends GameEvent {
  final UnitState unit;
  final Buff buff;

  BuffRemovedEvent({required this.unit, required this.buff});
}

class SkillExecutedEvent extends GameEvent {
  final UnitState caster;
  final Skill skill;

  SkillExecutedEvent({required this.caster, required this.skill});
}

class TurnStartEvent extends GameEvent {
  final UnitState unit;

  TurnStartEvent({required this.unit});
}

class TurnEndEvent extends GameEvent {
  final UnitState unit;

  TurnEndEvent({required this.unit});
}

class BattleStartEvent extends GameEvent {}

class BattleEndEvent extends GameEvent {
  final bool playerWon;

  BattleEndEvent({required this.playerWon});
}
