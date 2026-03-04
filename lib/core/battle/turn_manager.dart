import '../../common/constants.dart';
import '../map/board.dart';
import '../unit/unit_state.dart';
import 'turn_delegate.dart';

const double maxActionGauge = GameConstants.maxActionGauge;

class TurnManager {
  final List<UnitState> _units = [];
  final Map<Position, UnitState> _positionIndex = {};

  // 行动队列 (当前已满的单位)
  final List<UnitState> _actionQueue = [];

  UnitState? _activeUnit;

  /// 回合生命周期委托（由 BattleController 设置）
  TurnDelegate? delegate;

  UnitState? get activeUnit => _activeUnit;
  List<UnitState> get actionQueue => List.unmodifiable(_actionQueue);
  List<UnitState> get units => List.unmodifiable(_units);

  TurnManager();

  /// 根据坐标查找战斗单位（O(1) 空间索引查询）
  UnitState? getUnitAt(int x, int y) => _positionIndex[(x: x, y: y)];

  /// 更新单位位置并维护空间索引
  void updateUnitPosition(UnitState unit, int newX, int newY) {
    final oldPos = (x: unit.x, y: unit.y);
    if (_positionIndex[oldPos] == unit) _positionIndex.remove(oldPos);
    unit.x = newX;
    unit.y = newY;
    _positionIndex[(x: newX, y: newY)] = unit;
  }

  void registerUnit(UnitState unit) {
    if (!_units.contains(unit)) {
      _units.add(unit);
      _positionIndex[(x: unit.x, y: unit.y)] = unit;
      // 初始随机化一点ATB，防止同速完全同步
      unit.actionGauge = (unit.currentSpeed * 5).toDouble().clamp(0, maxActionGauge * 0.5);
    }
  }

  Future<void> removeUnit(UnitState unit) async {
    _units.remove(unit);
    _actionQueue.remove(unit);
    final pos = (x: unit.x, y: unit.y);
    if (_positionIndex[pos] == unit) _positionIndex.remove(pos);
    if (_activeUnit == unit) {
      _activeUnit = null;
      await _advanceTurn();
    }
  }

  Future<void> startBattle() async {
    await _advanceTurn();
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

    await _advanceTurn();
  }

  /// 迭代式回合推进：填充行动队列 → 取出下一个单位 → 开始回合。
  ///
  /// 如果单位在回合开始阶段（buff/cell 效果）死亡，
  /// 循环继续取下一个单位，避免递归调用栈增长。
  Future<void> _advanceTurn() async {
    while (true) {
      // 1. 确保行动队列有单位
      if (_actionQueue.isEmpty) {
        _fillActionQueue();
      }
      if (_actionQueue.isEmpty) break; // 全员 0 速或无单位

      // 2. 取出下一个行动单位（跳过已死亡的）
      final unit = _actionQueue.removeAt(0);
      if (unit.isDead) continue;
      _activeUnit = unit;

      // 3. 回合初始化
      unit.beginTurnRecord();

      // 4. 处理 Buff / Cell 回合开始效果
      await delegate?.onBuffTurnStart(unit);
      await delegate?.onCellTurnStart(unit);

      // 5. 效果可能致死（如毒），检查死亡后继续循环取下一个
      if (unit.isDead) {
        _activeUnit = null;
        await delegate?.onUnitDeath(unit);
        continue; // 迭代取下一个，不递归
      }

      // 6. 正常开始回合（玩家交互或 AI 执行）
      await delegate?.onTurnStart(unit);
      break; // 回合已开始，等待 endTurn() 被调用
    }
  }

  /// 推进 ATB 时间直到至少一个单位行动槽满，填入 _actionQueue。
  void _fillActionQueue() {
    if (_units.isEmpty) return;

    while (_actionQueue.isEmpty) {
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

      // 按速度排序，处理同帧满的情况（速度快的优先）
      _actionQueue.sort((a, b) => b.currentSpeed.compareTo(a.currentSpeed));
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
}
