import 'dart:ui';
import '../../core/ai/simple_ai.dart';
import '../../core/skills/skill.dart';

enum UnitFaction {
  player,
  enemy,
  ally,
  neutral;

  /// 判断本阵营是否与 [other] 敌对
  bool isHostileTo(UnitFaction other) => switch ((this, other)) {
    (player, enemy) || (enemy, player) => true,
    (ally, enemy) || (enemy, ally) => true,
    _ => false,
  };
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

  /// 基础攻击力
  int get attack;

  /// 基础速度 (决定行动槽积累速度)
  int get speed;

  /// 最大生命值
  int get maxHp;

  MoveSkill get moveSkill;
  List<Skill> get skills;

  /// AI 策略（非玩家单位使用）
  AIStrategy get aiStrategy => const AggressiveAI();

  Unit({
    required this.color,
    this.faction = UnitFaction.player,
  });
}
