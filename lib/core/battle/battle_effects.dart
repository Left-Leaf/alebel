import '../buffs/buff.dart';
import '../map/board.dart';
import '../skills/skill.dart';
import '../unit/unit_state.dart';
import 'battle_api.dart';
import 'battle_presenter.dart';

/// 共享的战斗效果实现
///
/// 提取 damageUnit、healUnit、addBuff、removeBuff、executeSkill 的通用逻辑，
/// 消除 BattleController 和测试 mock 之间的代码重复。
///
/// 使用者需同时 `implements BattleAPI`，mixin 中的 `this` 即为 BattleAPI 实例。
mixin BattleEffects implements BattleAPI {
  BattlePresenter get presenter;

  /// 单位死亡时的回调，由实现者自定义行为
  Future<void> onUnitKilled(UnitState unit);

  @override
  Future<void> damageUnit(UnitState target, int amount,
      {UnitState? attacker}) async {
    // 1. 目标 Buff 减伤钩子（快照迭代，防止钩子中修改 buffs 列表）
    var finalAmount = amount;
    for (final buff in List.of(target.buffs)) {
      finalAmount = await buff.onDamageTaken(target, finalAmount,
          attacker: attacker, api: this);
    }

    // 2. 扣血
    final damage = target.takeDamage(finalAmount);
    await presenter.showDamage(target, damage);

    // 3. 攻击者 Buff 造成伤害后钩子（快照迭代）
    if (attacker != null) {
      for (final buff in List.of(attacker.buffs)) {
        await buff.onDamageDealt(attacker, target, damage, api: this);
      }
    }

    if (target.isDead) {
      await onUnitKilled(target);
    }
  }

  @override
  Future<void> healUnit(UnitState target, int amount) async {
    final healed = target.heal(amount);
    if (healed > 0) {
      await presenter.showHeal(target, healed);
    }
  }

  @override
  Future<void> addBuff(UnitState target, Buff buff) async {
    target.addBuff(buff);
    await presenter.showBuffApplied(target, buff);
  }

  @override
  Future<void> removeBuff(UnitState target, Buff buff) async {
    target.removeBuff(buff);
    await presenter.showBuffRemoved(target, buff);
  }

  @override
  Future<bool> executeSkill(
      UnitState unit, Skill skill, Position target) async {
    if (!unit.canUse(skill)) return false;
    final executed = await skill.onTap(unit, target, this);
    if (executed) {
      if (skill.cost > 0) unit.spendAp(skill.cost);
      unit.recordSkill(skill);
    }
    return executed;
  }
}
