import 'package:alebel/models/units/unit_base.dart';

import '../buffs/buff.dart';
import '../map/board.dart'; // Position
import '../skills/skill.dart';
import 'action_gauge_mixin.dart';
import 'action_point_mixin.dart';
import 'attack_mixin.dart';
import 'health_mixin.dart';
import 'skill_record_mixin.dart';
import 'vision_mixin.dart';

class UnitState
    with HealthMixin, AttackMixin, ActionPointMixin, VisionMixin, ActionGaugeMixin, SkillRecordMixin {
  final Unit unit;

  // Buffs
  final List<Buff> buffs = [];
  int x;
  int y;

  // 移动预览位置 (如果非空，表示正在预览移动到该位置)
  Position? previewPosition;

  // HealthMixin
  @override
  int maxHp;
  @override
  int currentHp;

  // AttackMixin
  @override
  int currentAttack;

  // ActionPointMixin
  @override
  int maxActionPoints;
  @override
  int currentActionPoints;
  @override
  int recoveryActionPoints;

  // VisionMixin
  @override
  int currentVisionRange;

  // ActionGaugeMixin
  @override
  int currentSpeed;
  @override
  double actionGauge = 0;

  // SkillRecordMixin
  @override
  late Skill focusSkill = unit.moveSkill;

  UnitState({required this.unit, required this.x, required this.y})
    : currentVisionRange = unit.visionRange,
      maxHp = unit.maxHp,
      currentHp = unit.maxHp,
      currentAttack = unit.attack,
      maxActionPoints = unit.moveRange,
      currentActionPoints = unit.moveRange,
      recoveryActionPoints = unit.moveRange,
      currentSpeed = unit.speed;

  void addBuff(Buff buff) {
    buffs.add(buff);
    recalculateAttributes();
  }

  void removeBuff(Buff buff) {
    buffs.remove(buff);
    recalculateAttributes();
  }

  void recalculateAttributes() {
    // 1. Reset to base
    currentVisionRange = unit.visionRange;
    maxHp = unit.maxHp;
    currentAttack = unit.attack;
    // 注意：如果是百分比修改 HP，这里可能需要特殊处理。目前假设只修改上限。
    // currentHp 不受影响，除非超过 maxHp

    maxActionPoints = unit.moveRange;
    recoveryActionPoints = unit.moveRange;
    currentSpeed = unit.speed;

    // 2. Sort buffs
    buffs.sort((a, b) => a.priority.compareTo(b.priority));

    // 3. Apply
    for (final buff in buffs) {
      buff.apply(this);
    }

    // 4. Clamp state
    clampHp();
  }
}
