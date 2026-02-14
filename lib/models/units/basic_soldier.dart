import '../../core/skills/skill.dart';
import '../../core/skills/attack_skill.dart';
import '../../core/skills/move_skill.dart';
import 'unit_base.dart';

class BasicSoldier extends Unit {
  @override
  final int moveRange;

  @override
  final int visionRange;

  @override
  final int attackRange;

  @override
  final int speed;

  @override
  final int maxHp;

  @override
  final MoveSkill moveSkill;

  @override
  final List<Skill> skills;

  BasicSoldier({
    required super.color,
    super.faction,
    this.moveRange = 5,
    this.visionRange = 5,
    this.attackRange = 1,
    this.speed = 10,
    this.maxHp = 100,
  }) : 
       moveSkill = MoveSkill(),
       skills = [AttackSkill()];
}
