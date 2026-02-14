import '../unit/unit_state.dart';

// 行动槽最大值
const double maxActionGauge = 1000.0;

class TurnManager {
  final List<UnitState> _units = [];
  
  // 行动队列 (当前已满的单位)
  final List<UnitState> _actionQueue = [];
  
  UnitState? _activeUnit;
  
  // 事件回调
  void Function(UnitState unit)? onUnitTurnStart;
  void Function(UnitState unit)? onUnitTurnEnd;

  UnitState? get activeUnit => _activeUnit;
  List<UnitState> get actionQueue => List.unmodifiable(_actionQueue);

  void registerUnit(UnitState unit) {
    if (!_units.contains(unit)) {
      _units.add(unit);
      // 初始随机化一点ATB，防止同速完全同步
      unit.actionGauge = (unit.currentSpeed * 5).toDouble().clamp(0, maxActionGauge * 0.5);
    }
  }

  void removeUnit(UnitState unit) {
    _units.remove(unit);
    _actionQueue.remove(unit);
    if (_activeUnit == unit) {
      _activeUnit = null;
      _tick(); // 当前行动单位移除，继续跑条
    }
  }

  void startBattle() {
    _tick();
  }

  /// 结束当前单位的回合
  void endTurn() {
    if (_activeUnit != null) {
      final unit = _activeUnit!;

      // 处理 Buff 回合结束
      // 收集过期的 buff
      final expiredBuffs = <dynamic>[];
      for (final buff in unit.buffs) {
        if (buff.onTurnEnd(unit)) {
          expiredBuffs.add(buff);
        }
      }
      // 移除过期 buff
      for (final buff in expiredBuffs) {
        unit.removeBuff(buff);
        print("Buff expired: ${buff.name} on ${unit.unit.faction}");
      }
      
      unit.actionGauge = 0; // 重置行动槽
      
      // 恢复行动点
      unit.currentActionPoints = unit.recoveryActionPoints.clamp(0, unit.maxActionPoints);
          
      print("Turn End: ${unit.unit.faction} Unit. AP reset to ${unit.currentActionPoints}");

      onUnitTurnEnd?.call(unit);
      _activeUnit = null;
    }
    
    // 检查队列或继续跑条
    if (_actionQueue.isNotEmpty) {
      _startUnitTurn(_actionQueue.removeAt(0));
    } else {
      _tick();
    }
  }

  // ATB 推进逻辑
  void _tick() {
    // 如果已有行动队列，直接取出执行
    if (_actionQueue.isNotEmpty) {
      _startUnitTurn(_actionQueue.removeAt(0));
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
      _startUnitTurn(_actionQueue.removeAt(0));
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

  void _startUnitTurn(UnitState unit) {
    _activeUnit = unit;
    
    // 注意：行动点恢复逻辑已移动到 endTurn
    // 这里只负责触发回合开始事件
    
    // 处理 Buff 回合开始
    for (final buff in unit.buffs) {
      buff.onTurnStart(unit);
    }
    // 可能 Buff 会影响属性，所以确保属性最新（onTurnStart 可能会修改 buff 状态）
    // 但通常 apply 已经在 add/remove 时调用了。
    // 如果 Buff 有“每回合造成伤害”等逻辑，这里处理。
    
    print("Turn Start: ${unit.unit.faction} Unit at (${unit.x}, ${unit.y}) AP: ${unit.currentActionPoints}");
    onUnitTurnStart?.call(unit);
  }
}
