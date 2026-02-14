import '../skills/skill.dart';
import 'package:alebel/models/units/unit_base.dart';
import '../map/board.dart'; // Position
import '../buffs/buff.dart';

class UnitState {
  final Unit unit;
  
  // Buffs
  final List<Buff> buffs = [];
  int x;
  int y;

  // 移动预览位置 (如果非空，表示正在预览移动到该位置)
  Position? previewPosition;

  // 动态属性（运行时可能会改变）
  int currentVisionRange;
  
  // 生命值
  int maxHp;
  int currentHp;

  // 行动点相关
  int maxActionPoints; // 最大行动点数
  int currentActionPoints; // 当前剩余行动点
  int recoveryActionPoints; // 回合结束恢复的行动点数
  
  /// 动态速度 (受Buff/Debuff影响)
  int currentSpeed;
  
  /// 行动槽值 (0-1000, 满时行动)
  double actionGauge = 0;

  late Skill currentSkill;

  UnitState({
    required this.unit,
    required this.x,
    required this.y,
  }) : // currentMoveRange = unit.moveRange,
       currentVisionRange = unit.visionRange,
       maxHp = unit.maxHp,
       currentHp = unit.maxHp,
       maxActionPoints = unit.moveRange, // 默认最大行动点 = 移动力
       currentActionPoints = unit.moveRange,
       recoveryActionPoints = unit.moveRange, // 默认每回合恢复全部
       currentSpeed = unit.speed {
    currentSkill = unit.moveSkill;
  }

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
    if (currentHp > maxHp) currentHp = maxHp;
  }
}
