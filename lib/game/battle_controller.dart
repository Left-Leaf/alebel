import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart' show Colors, Color;

import '../common/constants.dart';
import '../core/ai/ai_action.dart';
import '../core/battle/battle_api.dart';
import '../core/buffs/buff.dart';
import '../core/events/game_event.dart';
import '../core/map/board.dart';
import '../core/map/game_map.dart';
import '../core/skills/skill.dart';
import '../core/unit/unit_state.dart';
import '../models/units/unit_base.dart';
import '../presentation/components/cell_component.dart';
import '../presentation/components/unit_component.dart';
import 'board_component.dart';

/// 战斗交互控制器
///
/// 在进入战斗模式时加载，离开时卸载。
/// 实现 [BattleAPI]，技能通过该接口直接执行效果和控制交互状态。
class BattleController extends Component implements BattleAPI {
  final BoardComponent board;
  bool _active = true;
  final List<StreamSubscription> _eventSubscriptions = [];

  // --- 焦点系统 ---

  CellComponent? _focusCell;

  CellComponent? get focusCell => _focusCell;

  set focusCell(CellComponent? cell) {
    if (_focusCell == cell) return;

    // 清理旧焦点单位的状态
    final oldUnit = focusUnit;
    if (oldUnit != null) {
      oldUnit.state.previewPosition = null;
    }

    // 切换 cell 选中态
    _focusCell?.isSelected = false;
    _focusCell = cell;
    _focusCell?.isSelected = true;

    // 联动刷新
    _updatePreviewUnit();
    _updateRangeLayer();
  }

  /// 当前焦点格子上的单位（派生属性）
  UnitComponent? get focusUnit {
    if (_focusCell == null) return null;
    return board.unitLayer.getUnitAt(_focusCell!.gridX, _focusCell!.gridY);
  }

  // --- 悬停状态 ---

  CellComponent? _hoveredCell;

  CellComponent? get hoveredCell => _hoveredCell;

  // --- 预览/投影单位 ---

  UnitComponent? _previewUnit;

  BattleController({required this.board});

  // --- SkillContext (用于 getHighlightPositions) ---

  SkillContext get _skillContext => SkillContext(
    gameMap: board.gameMap,
    activeUnit: board.turnManager.activeUnit,
    getUnitAt: board.turnManager.getUnitAt,
  );

  // ══════════════════════════════════════
  // BattleAPI 实现
  // ══════════════════════════════════════

  @override
  UnitState? get activeUnit => board.turnManager.activeUnit;

  @override
  UnitState? getUnitAt(int x, int y) => board.turnManager.getUnitAt(x, y);

  @override
  GameMap get gameMap => board.gameMap;

  @override
  void setFocus(Position? target) {
    if (target != null) {
      focusCell = board.gridLayer.getCell(target.x, target.y);
    } else {
      focusCell = null;
    }
  }

  @override
  void setPreview(UnitState caster, Position target) {
    caster.previewPosition = target;
    _updatePreviewUnit();
    _updateRangeLayer();
  }

  @override
  void clearPreview(UnitState caster) {
    caster.previewPosition = null;
    _updatePreviewUnit();
    _updateRangeLayer();
  }

  @override
  void switchSkill(UnitState caster, Skill skill) {
    caster.focusSkill = skill;
    _updateRangeLayer();
  }

  @override
  Future<void> moveUnit(UnitState unit, List<Position> path) async {
    final unitComponent = board.unitLayer.getUnitAt(unit.x, unit.y);
    if (unitComponent == null) return;

    final startX = unit.x;
    final startY = unit.y;

    for (int i = 1; i < path.length; i++) {
      if (unit.currentActionPoints <= 0) break;

      final nextPoint = path[i];

      // 逐步验证：检查下一步是否被阻挡
      if (board.gameMap.blocksPass(nextPoint.x, nextPoint.y)) break;
      final occupant = board.turnManager.getUnitAt(nextPoint.x, nextPoint.y);
      if (occupant != null && occupant != unit) break;

      // Flame 动画
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

    unit.previewPosition = null;

    if (unit.x != startX || unit.y != startY) {
      board.eventBus.fire(UnitMovedEvent(
        unit: unit,
        fromX: startX,
        fromY: startY,
        toX: unit.x,
        toY: unit.y,
      ));
    }
  }

  @override
  void damageUnit(UnitState target, int amount) {
    final damage = target.takeDamage(amount);
    board.eventBus.fire(UnitDamagedEvent(unit: target, damage: damage));
    if (target.isDead) {
      handleUnitDeath(target);
    }
  }

  @override
  void healUnit(UnitState target, int amount) {
    final healed = target.heal(amount);
    if (healed > 0) {
      board.eventBus.fire(UnitHealedEvent(unit: target, amount: healed));
    }
  }

  @override
  void addBuff(UnitState target, Buff buff) {
    target.addBuff(buff);
    board.eventBus.fire(BuffAppliedEvent(unit: target, buff: buff));
  }

  // ══════════════════════════════════════
  // 初始化 / 清理
  // ══════════════════════════════════════

  void setup() {
    _eventSubscriptions.addAll([
      board.eventBus.on<TurnStartEvent>().listen((e) => _onUnitTurnStart(e.unit)),
      board.eventBus.on<TurnEndEvent>().listen((e) => _onUnitTurnEnd(e.unit)),
    ]);

    board.turnManager.onUnitDeath = (unit) => handleUnitDeath(unit);
  }

  void cleanup() {
    _active = false;
    focusCell = null;
    board.rangeLayer.clear();
    _hoveredCell = null;

    for (final sub in _eventSubscriptions) {
      sub.cancel();
    }
    _eventSubscriptions.clear();

    board.turnManager.onUnitDeath = null;
  }

  // --- 回合回调 ---

  void _onUnitTurnStart(UnitState unit) {
    if (unit.unit.faction == UnitFaction.player) {
      focusCell = board.gridLayer.getCell(unit.x, unit.y);
    } else {
      _executeAiTurn(unit);
    }
  }

  void _onUnitTurnEnd(UnitState unit) {
    if (focusUnit?.state == unit) {
      focusCell = null;
    }
  }

  Future<void> _executeAiTurn(UnitState unit) async {
    final ctx = AIContext(
      gameMap: board.gameMap,
      units: board.turnManager.units,
      getUnitAt: board.turnManager.getUnitAt,
    );

    final actions = unit.unit.aiStrategy.decideTurn(unit, ctx);

    for (final action in actions) {
      await _handleAIAction(action, unit);
    }

    board.turnManager.endTurn();
  }

  Future<void> _handleAIAction(AIAction action, UnitState unit) async {
    switch (action) {
      case AIMove(:final path):
        await moveUnit(unit, path);

      case AIAttack(:final target, :final attackPower):
        damageUnit(target, attackPower);
    }
  }

  // --- 单位死亡 / 战斗结束 ---

  void handleUnitDeath(UnitState deadUnit) {
    board.turnManager.removeUnit(deadUnit);
    final unitComponent = board.unitLayer.getUnitAt(deadUnit.x, deadUnit.y);
    if (unitComponent != null) {
      board.unitLayer.removeUnit(unitComponent);
      if (unitComponent == board.playerUnit) board.playerUnit = null;
    }
    if (focusUnit?.state == deadUnit) focusCell = null;
    board.eventBus.fire(UnitDeathEvent(unit: deadUnit));
    board.updateFog();
    _checkBattleEnd();
  }

  void _checkBattleEnd() {
    final hasPlayer = board.unitLayer.units.any((u) => u.faction == UnitFaction.player);
    final hasEnemy = board.unitLayer.units.any((u) => u.faction == UnitFaction.enemy);
    if (!hasEnemy) {
      cleanup();
      board.eventBus.fire(BattleEndEvent(playerWon: true));
      board.game.startTransitionToExploration();
    } else if (!hasPlayer) {
      cleanup();
      board.eventBus.fire(BattleEndEvent(playerWon: false));
    }
  }

  // --- 单元格交互 ---

  void onCellTap(CellComponent cell) async {
    if (!_active) return;

    final source = focusUnit;
    if (source != null) {
      final skill = source.state.focusSkill;
      final target = (x: cell.gridX, y: cell.gridY);
      final executed = await skill.onTap(source.state, target, this);
      if (executed) {
        source.state.recordSkill(skill);
        board.eventBus.fire(SkillExecutedEvent(caster: source.state, skill: skill));
      }
    } else {
      focusCell = (focusCell == cell) ? null : cell;
    }
  }

  void onCellHoverEnter(CellComponent cell) {
    if (!_active) return;
    if (_hoveredCell != cell) {
      _hoveredCell = cell;
    }
  }

  void onCellHoverExit(CellComponent cell) {
    if (!_active) return;
    if (_hoveredCell == cell) {
      _hoveredCell = null;
    }
  }

  // --- 范围层 / 预览单位 ---

  void updateRangeLayer() => _updateRangeLayer();

  void _updateRangeLayer() {
    final unit = focusUnit;
    if (unit != null && board.turnManager.activeUnit == unit.state) {
      final highlights = unit.state.focusSkill.getHighlightPositions(unit.state, _skillContext);
      final coloredHighlights = highlights
          .map((h) => (x: h.pos.x, y: h.pos.y, color: _highlightColor(h.type)))
          .toList();
      board.rangeLayer.updateRanges(coloredHighlights);
    } else {
      board.rangeLayer.clear();
    }
  }

  static Color _highlightColor(HighlightType type) {
    return switch (type) {
      HighlightType.moveConfirmed => Colors.blue.withValues(alpha: 0.3),
      HighlightType.moveUncertain => Colors.blue.withValues(alpha: 0.15),
      HighlightType.attack => Colors.red.withValues(alpha: 0.3),
    };
  }

  void updatePreviewUnit() => _updatePreviewUnit();

  void _updatePreviewUnit() {
    final unit = focusUnit;
    final previewPos = unit?.state.previewPosition;

    if (previewPos != null) {
      if (_previewUnit == null) {
        final projectionState = UnitState(unit: unit!.state.unit, x: previewPos.x, y: previewPos.y);
        _previewUnit = UnitComponent(state: projectionState)..visualOpacity = 0.5;
        board.unitLayer.add(_previewUnit!);
      } else if (_previewUnit!.gridX != previewPos.x || _previewUnit!.gridY != previewPos.y) {
        board.unitLayer.remove(_previewUnit!);
        final projectionState = UnitState(unit: unit!.state.unit, x: previewPos.x, y: previewPos.y);
        _previewUnit = UnitComponent(state: projectionState)..visualOpacity = 0.5;
        board.unitLayer.add(_previewUnit!);
      }
    } else {
      if (_previewUnit != null) {
        board.unitLayer.remove(_previewUnit!);
        _previewUnit = null;
      }
    }
  }
}
