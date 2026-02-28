mixin ActionPointMixin {
  int get maxActionPoints;
  set maxActionPoints(int value);
  int get currentActionPoints;
  set currentActionPoints(int value);
  int get recoveryActionPoints;
  set recoveryActionPoints(int value);

  /// 消耗行动点，返回实际消耗量
  int spendAp(int amount) {
    if (amount <= 0) return 0;
    final actual = amount.clamp(0, currentActionPoints);
    currentActionPoints -= actual;
    return actual;
  }

  bool get hasAp => currentActionPoints > 0;

  /// 回合结束时恢复行动点
  void recoverAp() {
    currentActionPoints = recoveryActionPoints.clamp(0, maxActionPoints);
  }
}
