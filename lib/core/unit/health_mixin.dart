mixin HealthMixin {
  int get maxHp;
  set maxHp(int value);
  int get currentHp;
  set currentHp(int value);

  bool get isDead => currentHp <= 0;
  bool get isAlive => currentHp > 0;

  /// 受到伤害，返回实际扣除的HP
  int takeDamage(int amount) {
    if (amount <= 0 || isDead) return 0;
    final actual = amount.clamp(0, currentHp);
    currentHp -= actual;
    if (isDead) onDeath();
    return actual;
  }

  /// 恢复生命，返回实际恢复的HP
  int heal(int amount) {
    if (amount <= 0 || isDead) return 0;
    final before = currentHp;
    currentHp = (currentHp + amount).clamp(0, maxHp);
    return currentHp - before;
  }

  /// 将当前HP限制在maxHp以内
  void clampHp() {
    if (currentHp > maxHp) currentHp = maxHp;
  }

  /// 死亡时调用，子类可覆写以实现回调
  void onDeath() {}
}
