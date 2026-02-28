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
}
