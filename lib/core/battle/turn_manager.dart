import '../../common/constants.dart';
import '../unit/unit_state.dart';
import 'turn_delegate.dart';

const double maxActionGauge = GameConstants.maxActionGauge;

class TurnManager {
  final List<UnitState> _units = [];

  // 行动队列 (当前已满的单位)
  final List<UnitState> _actionQueue = [];

  UnitState? _activeUnit;

  /// 回合生命周期委托（由 BattleController 设置）
  TurnDelegate? delegate;

  UnitState? get activeUnit => _activeUnit;
  List<UnitState> get actionQueue => List.unmodifiable(_actionQueue);
  List<UnitState> get units => List.unmodifiable(_units);

  TurnManager();

  /// 根据坐标查找战斗单位（供 SkillContext 使用）
  UnitState? getUnitAt(int x, int y) {
    for (final unit in _units) {
      if (unit.x == x && unit.y == y) return unit;
    }
    return null;
  }

  void registerUnit(UnitState unit) {
    if (!_units.contains(unit)) {
      _units.add(unit);
      // 初始随机化一点ATB，防止同速完全同步
      unit.actionGauge = (unit.currentSpeed * 5).toDouble().clamp(0, maxActionGauge * 0.5);
    }
  }

  Future<void> removeUnit(UnitState unit) async {
    _units.remove(unit);
    _actionQueue.remove(unit);
    if (_activeUnit == unit) {
      _activeUnit = null;
      await _tick(); // 当前行动单位移除，继续跑条
    }
  }

  Future<void> startBattle() async {
    await _tick();
  }

  /// 结束当前单位的回合
  Future<void> endTurn() async {
    if (_activeUnit != null) {
      final unit = _activeUnit!;

      // 处理 Buff 回合结束
      await delegate?.onBuffTurnEnd(unit);

      unit.actionGauge = 0; // 重置行动槽

      // 恢复行动点
      unit.recoverAp();

      await delegate?.onTurnEnd(unit);
      _activeUnit = null;
    }

    // 检查队列或继续跑条
    if (_actionQueue.isNotEmpty) {
      await _startUnitTurn(_actionQueue.removeAt(0));
    } else {
      await _tick();
    }
  }

  // ATB 推进逻辑
  Future<void> _tick() async {
    // 如果已有行动队列，直接取出执行
    if (_actionQueue.isNotEmpty) {
      await _startUnitTurn(_actionQueue.removeAt(0));
      return;
    }

    // 模拟时间推进，直到至少有一个单位行动槽满
    while (_actionQueue.isEmpty && _units.isNotEmpty) {
      // 找出距离满槽最近的时间差
      double minTickToFull = double.infinity;

      for (final unit in _units) {
        if (unit.currentSpeed <= 0) continue;
        final needed = maxActionGauge - unit.actionGauge;
        final ticks = needed / unit.currentSpeed;
        if (ticks < minTickToFull) {
          minTickToFull = ticks;
        }
      }

      if (minTickToFull == double.infinity) break; // 防止死循环(全员0速)

      // 推进时间
      for (final unit in _units) {
         unit.actionGauge += unit.currentSpeed * minTickToFull;

         // 修正浮点误差，允许微小溢出
         if (unit.actionGauge >= maxActionGauge - 0.001) {
           unit.actionGauge = maxActionGauge;
           if (!_actionQueue.contains(unit)) {
             _actionQueue.add(unit);
           }
         }
      }

      // 按溢出量/速度排序，处理同帧满的情况 (速度快的优先，或溢出多的优先)
      // 这里简单处理：速度快的优先
      _actionQueue.sort((a, b) => b.currentSpeed.compareTo(a.currentSpeed));
    }

    if (_actionQueue.isNotEmpty) {
      await _startUnitTurn(_actionQueue.removeAt(0));
    }
  }

  /// 获取预测的行动顺序
  List<UnitState> getPredictedTurnOrder(int count) {
    final result = <UnitState>[];

    // 1. Add currently ready units
    result.addAll(_actionQueue);

    // 2. Simulate for the rest
    if (result.length < count) {
      // Create simulation state
      final simUnits = <UnitState, double>{};

      for (final unit in _units) {
        if (_actionQueue.contains(unit)) {
          // Already in queue, will act and reset to 0
          simUnits[unit] = 0.0;
        } else if (unit == _activeUnit) {
          // Currently acting, will reset to 0
          simUnits[unit] = 0.0;
        } else {
          // Waiting
          simUnits[unit] = unit.actionGauge;
        }
      }

      int needed = count - result.length;

      // Safety break
      int iterations = 0;
      while (needed > 0 && iterations < count * 2 + 20) {
        iterations++;

        // Find min time to next full
        double minTicks = double.infinity;
        UnitState? nextUnit;

        for (final unit in _units) {
           final speed = unit.currentSpeed;
           if (speed <= 0) continue;

           final gauge = simUnits[unit] ?? 0.0;
           final remaining = maxActionGauge - gauge;
           final ticks = remaining / speed;

           if (ticks < minTicks) {
             minTicks = ticks;
             nextUnit = unit;
           } else if (ticks == minTicks) {
             // Tie-breaker
             if (nextUnit != null && speed > nextUnit.currentSpeed) {
                nextUnit = unit;
             }
           }
        }

        if (nextUnit == null || minTicks == double.infinity) break;

        // Advance time
        for (final unit in _units) {
             final old = simUnits[unit] ?? 0.0;
             simUnits[unit] = old + unit.currentSpeed * minTicks;
        }

        // Add nextUnit to result
        result.add(nextUnit);
        // Reset its gauge
        simUnits[nextUnit] = 0.0;

        needed--;
      }
    }

    return result.take(count).toList();
  }

  Future<void> _startUnitTurn(UnitState unit) async {
    _activeUnit = unit;

    // 记录新回合
    unit.beginTurnRecord();

    // 处理 Buff 回合开始
    await delegate?.onBuffTurnStart(unit);

    // 处理 Cell 回合开始效果
    await delegate?.onCellTurnStart(unit);

    // Buff / Cell 可能造成伤害（如毒），检查死亡
    if (unit.isDead) {
      _activeUnit = null;
      await delegate?.onUnitDeath(unit);
      // 继续下一个单位
      if (_actionQueue.isNotEmpty) {
        await _startUnitTurn(_actionQueue.removeAt(0));
      } else {
        await _tick();
      }
      return;
    }

    await delegate?.onTurnStart(unit);
  }
}
