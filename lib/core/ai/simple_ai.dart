import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../common/constants.dart';
import '../../game/board_component.dart';
import '../../presentation/components/cell_component.dart';
import '../events/game_event.dart';
import '../map/board.dart';
import '../unit/unit_state.dart';
import '../../models/units/unit_base.dart';

class SimpleAI {
  final BoardComponent board;

  SimpleAI(this.board);

  Future<void> executeTurn(UnitState unit) async {
    // 1. 找最近的玩家单位（曼哈顿距离）
    final target = _findNearestEnemy(unit);
    if (target == null) return;

    // 2. 若已在攻击范围 → 攻击
    if (_isInAttackRange(unit, target)) {
      _performAttack(unit, target);
      return;
    }

    // 3. 寻路到目标最近的可达位置
    final paths = board.gameMap.getMovablePositions(
      (x: unit.x, y: unit.y),
      unit.currentActionPoints,
    );

    // 找距目标最近的可达位置
    Position? bestEnd;
    List<Position>? bestPath;
    int bestDistance = _manhattan(unit.x, unit.y, target.x, target.y);

    for (final (path, _) in paths) {
      if (path.length <= 1) continue;
      final end = path.last;

      // 检查终点没有其他单位
      final occupant = board.unitLayer.getUnitAt(end.x, end.y);
      if (occupant != null && occupant.state != unit) continue;

      final dist = _manhattan(end.x, end.y, target.x, target.y);
      if (dist < bestDistance) {
        bestDistance = dist;
        bestEnd = end;
        bestPath = path;
      }
    }

    // 4. 逐步移动
    if (bestPath != null && bestEnd != null) {
      await _moveAlongPath(unit, bestPath);
    }

    // 5. 移动后再次检查攻击范围
    if (_isInAttackRange(unit, target)) {
      _performAttack(unit, target);
    }
  }

  UnitState? _findNearestEnemy(UnitState unit) {
    UnitState? nearest;
    int minDist = 999999;

    for (final uc in board.unitLayer.units) {
      if (uc.faction == UnitFaction.player) {
        final dist = _manhattan(unit.x, unit.y, uc.state.x, uc.state.y);
        if (dist < minDist) {
          minDist = dist;
          nearest = uc.state;
        }
      }
    }

    return nearest;
  }

  bool _isInAttackRange(UnitState attacker, UnitState target) {
    final dist = _manhattan(attacker.x, attacker.y, target.x, target.y);
    return dist <= attacker.unit.attackRange;
  }

  void _performAttack(UnitState attacker, UnitState target) {
    final damage = target.takeDamage(attacker.currentAttack);
    board.eventBus.fire(UnitDamagedEvent(unit: target, damage: damage));
    if (target.isDead) {
      board.handleUnitDeath(target);
    }
  }

  Future<void> _moveAlongPath(UnitState unit, List<Position> path) async {
    final unitComponent = board.unitLayer.getUnitAt(unit.x, unit.y);
    if (unitComponent == null) return;

    for (int i = 1; i < path.length; i++) {
      if (unit.currentActionPoints <= 0) break;

      final nextPoint = path[i];

      // 检查目标点是否被阻挡
      final occupant = board.unitLayer.getUnitAt(nextPoint.x, nextPoint.y);
      if (occupant != null && occupant.state != unit) break;

      final targetPos = Vector2(
        (nextPoint.x + 0.5) * CellComponent.cellSize,
        (nextPoint.y + 0.5) * CellComponent.cellSize,
      );

      final completer = Completer<void>();
      board.add(
        MoveToEffect(
          targetPos,
          EffectController(speed: GameConstants.moveSpeed),
          target: unitComponent,
          onComplete: () {
            unit.x = nextPoint.x;
            unit.y = nextPoint.y;
            unit.currentActionPoints--;
            board.updateFog();
            completer.complete();
          },
        ),
      );

      await completer.future;
    }
  }

  int _manhattan(int x1, int y1, int x2, int y2) {
    return (x1 - x2).abs() + (y1 - y2).abs();
  }
}
