import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import '../core/ai/simple_ai.dart';
import '../core/events/game_event.dart';
import '../core/unit/unit_state.dart';
import '../models/units/unit_base.dart';
import '../presentation/components/cell_component.dart';
import '../presentation/components/unit_component.dart';
import 'board_component.dart';

/// 战斗交互控制器
///
/// 在进入战斗模式时加载，离开时卸载。
/// 包含所有战斗交互状态：焦点系统、悬停、范围显示、预览单位、AI、回合回调。
class BattleController extends Component {
  final BoardComponent board;
  late final SimpleAI _ai;
  bool _active = true;

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

  /// 初始化战斗（设置 AI、注册回合回调）
  void setup() {
    _ai = SimpleAI(board);

    board.turnManager.onUnitTurnStart = _onUnitTurnStart;
    board.turnManager.onUnitTurnEnd = _onUnitTurnEnd;
    board.turnManager.onUnitDeath = (unit) => handleUnitDeath(unit);
  }

  /// 清理所有战斗交互状态
  void cleanup() {
    _active = false;
    focusCell = null;
    board.rangeLayer.clear();
    _hoveredCell = null;

    board.turnManager.onUnitTurnStart = null;
    board.turnManager.onUnitTurnEnd = null;
    board.turnManager.onUnitDeath = null;
  }

  // --- 回合回调 ---

  void _onUnitTurnStart(UnitState unit) {
    print("Game: Turn started for ${unit.unit.faction}");
    if (unit.unit.faction == UnitFaction.player) {
      focusCell = board.gridLayer.getCell(unit.x, unit.y);
    } else {
      _executeAiTurn(unit);
    }
  }

  void _onUnitTurnEnd(UnitState unit) {
    print("Game: Turn ended for ${unit.unit.faction}");
    if (focusUnit?.state == unit) {
      focusCell = null;
    }
  }

  Future<void> _executeAiTurn(UnitState unit) async {
    await _ai.executeTurn(unit);
    board.turnManager.endTurn();
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
      print('Victory!');
      cleanup();
      board.eventBus.fire(BattleEndEvent(playerWon: true));
      board.game.startTransitionToExploration();
    } else if (!hasPlayer) {
      print('Defeat!');
      cleanup();
      board.eventBus.fire(BattleEndEvent(playerWon: false));
    }
  }

  // --- 单元格交互 ---

  void onCellTap(CellComponent cell) {
    if (!_active) return;

    final source = focusUnit;
    if (source != null) {
      final skill = source.state.focusSkill;
      final executed = skill.onCellTap(source.state, cell, board);
      if (executed) {
        source.state.recordSkill(skill);
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
      final highlights = unit.state.focusSkill.getHighlightPositions(unit.state, board);
      board.rangeLayer.updateRanges(highlights);
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
