import 'dart:ui';
import '../../core/skills/skill.dart';
import '../../core/skills/move_skill.dart';

enum UnitFaction {
  player,
  enemy,
  ally,
  neutral,
}

abstract class Unit {
  final Color color;
  final UnitFaction faction;

  /// 最大可移动行动点
  int get moveRange;

  /// 最大可见距离
  int get visionRange;

  /// 攻击范围
  int get attackRange;

  /// 基础速度 (决定行动槽积累速度)
  int get speed;

  /// 最大生命值
  int get maxHp;

  MoveSkill get moveSkill;
  List<Skill> get skills;

  Unit({
    required this.color,
    this.faction = UnitFaction.player,
  });
}
