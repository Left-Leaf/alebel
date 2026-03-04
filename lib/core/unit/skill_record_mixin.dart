import 'dart:math';

import '../skills/skill.dart';

mixin SkillRecordMixin {
  Skill get focusSkill;
  set focusSkill(Skill value);

  /// 每回合执行的Skill记录，外层索引为回合序号，内层为该回合执行的Skill列表
  final List<List<Skill>> turnSkillHistory = [];

  /// 开始新回合时调用，创建新的记录条目
  void beginTurnRecord() {
    turnSkillHistory.add([]);
  }

  /// 记录当前回合执行的Skill
  void recordSkill(Skill skill) {
    if (turnSkillHistory.isNotEmpty) {
      turnSkillHistory.last.add(skill);
    }
  }

  /// 当前回合索引（从 0 开始）
  int get currentTurnIndex => turnSkillHistory.length - 1;

  /// 本回合该技能的使用次数
  int usesThisTurn(Skill skill) {
    if (turnSkillHistory.isEmpty) return 0;
    return turnSkillHistory.last.where((s) => s == skill).length;
  }

  /// 该技能最后一次使用的回合索引（null = 从未使用）
  int? lastUsedTurnIndex(Skill skill) {
    for (var i = turnSkillHistory.length - 1; i >= 0; i--) {
      if (turnSkillHistory[i].any((s) => s == skill)) return i;
    }
    return null;
  }

  /// 该技能剩余冷却回合数（0 = 可用）
  int remainingCooldown(Skill skill) {
    if (skill.cooldown <= 0) return 0;
    final lastUsed = lastUsedTurnIndex(skill);
    if (lastUsed == null) return 0;
    return max(0, skill.cooldown - (currentTurnIndex - lastUsed));
  }
}
