import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../common/constants.dart';
import '../core/ai/ai_action.dart';
import '../core/battle/battle_api.dart';
import '../core/battle/battle_presenter.dart';
import '../core/battle/turn_delegate.dart';
import '../core/buffs/buff.dart';
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
/// 实现 [TurnDelegate]，接收 TurnManager 的回合生命周期通知。
class BattleController extends Component implements BattleAPI, TurnDelegate {
  final BoardComponent board;
  final BattlePresenter _presenter;
  bool _active = true;
  bool _locked = false;

  /// 交互是否被锁定（技能执行中、AI 行动中等）
  bool get isLocked => _locked;

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

  BattleController({required this.board, required BattlePresenter presenter})
      : _presenter = presenter;

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

    for (int i = 1; i < path.length; i++) {
      final nextPoint = path[i];

      // 计算移动消耗
      final cellState = board.gameMap.getCell(nextPoint.x, nextPoint.y);
      final cost = cellState.cell.moveCost;
      if (unit.currentActionPoints < cost) break;

      // 逐步验证：检查下一步是否被阻挡
      if (board.gameMap.blocksPass(nextPoint.x, nextPoint.y)) break;
      final occupant = board.turnManager.getUnitAt(nextPoint.x, nextPoint.y);
      if (occupant != null && occupant != unit && i == path.length - 1) break;

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
            unit.currentActionPoints -= cost;
            board.updateFog();
            completer.complete();
          },
        ),
      );

      await completer.future;

      // 触发 Cell 进入效果
      await cellState.cell.onUnitEnter(unit, api: this);
      if (unit.isDead) {
        await _handleUnitDeath(unit);
        break;
      }
    }

    unit.previewPosition = null;
  }

  @override
  Future<void> damageUnit(UnitState target, int amount, {UnitState? attacker}) async {
    // 1. 目标 Buff 减伤钩子
    var finalAmount = amount;
    for (final buff in target.buffs) {
      finalAmount = await buff.onDamageTaken(target, finalAmount, attacker: attacker, api: this);
    }

    // 2. 扣血
    final damage = target.takeDamage(finalAmount);
    await _presenter.showDamage(target, damage);

    // 3. 攻击者 Buff 造成伤害后钩子
    if (attacker != null) {
      for (final buff in attacker.buffs) {
        await buff.onDamageDealt(attacker, target, damage, api: this);
      }
    }

    if (target.isDead) {
      await _handleUnitDeath(target);
    }
  }

  @override
  Future<void> healUnit(UnitState target, int amount) async {
    final healed = target.heal(amount);
    if (healed > 0) {
      await _presenter.showHeal(target, healed);
    }
  }

  @override
  Future<void> addBuff(UnitState target, Buff buff) async {
    target.addBuff(buff);
    await _presenter.showBuffApplied(target, buff);
  }

  @override
  Future<void> removeBuff(UnitState target, Buff buff) async {
    target.removeBuff(buff);
    await _presenter.showBuffRemoved(target, buff);
  }

  @override
  Future<void> displaceUnit(UnitState unit, Position target) async {
    final startX = unit.x;
    final startY = unit.y;

    unit.x = target.x;
    unit.y = target.y;

    final unitComponent = board.unitLayer.getUnitAt(startX, startY);
    if (unitComponent != null) {
      unitComponent.position = Vector2(
        (target.x + 0.5) * CellComponent.cellSize,
        (target.y + 0.5) * CellComponent.cellSize,
      );
    }

    board.updateFog();

    final cellState = board.gameMap.getCell(target.x, target.y);
    await cellState.cell.onUnitEnter(unit, api: this);
    if (unit.isDead) await _handleUnitDeath(unit);
  }

  // ══════════════════════════════════════
  // TurnDelegate 实现
  // ══════════════════════════════════════

  @override
  Future<void> onTurnStart(UnitState unit) async {
    if (unit.unit.faction == UnitFaction.player) {
      focusCell = board.gridLayer.getCell(unit.x, unit.y);
    } else {
      await _executeAiTurn(unit);
    }
  }

  @override
  Future<void> onTurnEnd(UnitState unit) async {
    if (focusUnit?.state == unit) {
      focusCell = null;
    }
  }

  @override
  Future<void> onBuffTurnStart(UnitState unit) async {
    for (final buff in unit.buffs) {
      await buff.onTurnStart(unit, api: this);
    }
  }

  @override
  Future<void> onBuffTurnEnd(UnitState unit) async {
    final expiredBuffs = <Buff>[];
    for (final buff in unit.buffs) {
      if (await buff.onTurnEnd(unit, api: this)) expiredBuffs.add(buff);
    }
    for (final buff in expiredBuffs) {
      await removeBuff(unit, buff);
    }
  }

  @override
  Future<void> onCellTurnStart(UnitState unit) async {
    final cellState = board.gameMap.getCell(unit.x, unit.y);
    await cellState.cell.onTurnStart(unit, api: this);
  }

  @override
  Future<void> onUnitDeath(UnitState unit) async {
    await _handleUnitDeath(unit);
  }

  // ══════════════════════════════════════
  // 初始化 / 清理
  // ══════════════════════════════════════

  void setup() {
    board.turnManager.delegate = this;
  }

  void cleanup() {
    _active = false;
    focusCell = null;
    board.rangeLayer.clear();
    _hoveredCell = null;

    board.turnManager.delegate = null;
  }

  /// 玩家请求结束回合（UI 层应调用此方法而非直接调用 turnManager）
  void endTurn() {
    if (!_active || _locked) return;
    board.turnManager.endTurn();
  }

  // --- AI 回合 ---

  Future<void> _executeAiTurn(UnitState unit) async {
    _locked = true;
    try {
      final ctx = AIContext(
        gameMap: board.gameMap,
        units: board.turnManager.units,
        getUnitAt: board.turnManager.getUnitAt,
      );

      final actions = unit.unit.aiStrategy.decideTurn(unit, ctx);

      for (final action in actions) {
        await _handleAIAction(action, unit);
      }

      await board.turnManager.endTurn();
    } finally {
      _locked = false;
    }
  }

  Future<void> _handleAIAction(AIAction action, UnitState unit) async {
    await action.execute(unit, this);
  }

  // --- 单位死亡 / 战斗结束 ---

  Future<void> _handleUnitDeath(UnitState deadUnit) async {
    await board.turnManager.removeUnit(deadUnit);
    final unitComponent = board.unitLayer.getUnitAt(deadUnit.x, deadUnit.y);
    if (unitComponent != null) {
      board.unitLayer.removeUnit(unitComponent);
      if (unitComponent == board.playerUnit) board.playerUnit = null;
    }
    if (focusUnit?.state == deadUnit) focusCell = null;
    await _presenter.showDeath(deadUnit);
    board.updateFog();
    await _checkBattleEnd();
  }

  Future<void> _checkBattleEnd() async {
    final hasPlayer = board.unitLayer.units.any((u) => u.faction == UnitFaction.player);
    final hasEnemy = board.unitLayer.units.any((u) => u.faction == UnitFaction.enemy);
    if (!hasEnemy) {
      await _presenter.showBattleEnd(true);
      cleanup();
      board.game.startTransitionToExploration();
    } else if (!hasPlayer) {
      await _presenter.showBattleEnd(false);
      cleanup();
    }
  }

  // --- 单元格交互 ---

  void onCellTap(CellComponent cell) async {
    if (!_active || _locked) return;

    final source = focusUnit;
    if (source != null) {
      final skill = source.state.focusSkill;
      final target = (x: cell.gridX, y: cell.gridY);

      if (!source.state.canUse(skill)) return;

      _locked = true;
      try {
        final executed = await skill.onTap(source.state, target, this);
        if (executed) {
          if (skill.cost > 0) source.state.spendAp(skill.cost);
          source.state.recordSkill(skill);
        }
      } finally {
        _locked = false;
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
          .map((h) => (x: h.pos.x, y: h.pos.y, color: h.color))
          .toList();
      board.rangeLayer.updateRanges(coloredHighlights);
    } else {
      board.rangeLayer.clear();
    }
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
