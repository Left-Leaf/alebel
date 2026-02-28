import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import '../core/battle/turn_manager.dart';
import '../core/game_mode.dart';
import '../core/map/game_map.dart';
import '../core/unit/unit_state.dart';
import '../models/units/basic_soldier.dart';
import '../models/units/unit_base.dart';
import '../presentation/components/animatable_iso_decorator.dart';
import '../presentation/components/cell_component.dart';

import '../presentation/components/origin_point.dart';
import '../presentation/components/unit_component.dart';
import '../presentation/layers/fog_layer.dart';
import '../presentation/layers/grid_layer.dart';
import '../presentation/layers/range_layer.dart';
import '../presentation/layers/unit_layer.dart';
import '../presentation/ui/selection_overlay.dart';
import 'alebel_game.dart';

class BoardComponent extends PositionComponent with HasGameReference<AlebelGame> {
  late final GridLayer gridLayer;
  late final UnitLayer unitLayer;
  late final RangeLayer rangeLayer;
  late final FogLayer fogLayer;
  late GameMap gameMap;
  late final TurnManager turnManager;

  late final AnimatableIsoDecorator _isoDecorator;

  /// 玩家控制的单位
  UnitComponent? playerUnit;

  // 交互状态
  CellComponent? _hoveredCell;

  CellComponent? get hoveredCell => _hoveredCell;

  // --- 等角投影因子 ---

  double get isoFactor => _isoDecorator.factor;

  set isoFactor(double value) {
    _isoDecorator.factor = value;
  }

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
    return unitLayer.getUnitAt(_focusCell!.gridX, _focusCell!.gridY);
  }

  // 预览/投影单位 (Ghost Unit)
  UnitComponent? _previewUnit;

  // 棋盘外围边界宽度
  static const double borderWidth = CellComponent.cellSize;

  @override
  Future<void> onLoad() async {
    _isoDecorator = AnimatableIsoDecorator(factor: 0.0);
    decorator.addLast(_isoDecorator);

    turnManager = TurnManager();
    gameMap = GameMap.standard();

    // 计算网格和边界的偏移量
    final boardOffset = Vector2(borderWidth, borderWidth);

    // 添加各层到棋盘容器（按渲染顺序，priority 从低到高）
    gridLayer = GridLayer()
      ..position = boardOffset
      ..priority = 1;
    add(gridLayer);

    add(OriginPoint()..priority = 2);

    fogLayer = FogLayer(map: gameMap)
      ..position = boardOffset
      ..priority = 3;
    add(fogLayer);

    add(
      SelectionOverlay()
        ..position = boardOffset
        ..priority = 4,
    );

    rangeLayer = RangeLayer()
      ..position = boardOffset
      ..priority = 5;
    add(rangeLayer);

    unitLayer = UnitLayer()
      ..position = boardOffset
      ..priority = 6;
    add(unitLayer);

    // 添加网格单元格 (作为逻辑实体)
    for (var x = 0; x < gameMap.width; x++) {
      for (var y = 0; y < gameMap.height; y++) {
        final cellState = gameMap.getCell(x, y);
        final cell = CellComponent(state: cellState);
        gridLayer.addCell(cell);
      }
    }

    // 创建玩家 Unit（探索模式 + 对战模式都存在）
    playerUnit = _addUnit(5, 5, Colors.blue, faction: UnitFaction.player);

    turnManager.registerUnit(playerUnit!.state);
    updateFog();
  }

  /// 初始化对战（添加敌方单位、注册回调、开始战斗）
  void initBattle() {
    // 添加额外的玩家单位和敌方单位
    _addUnit(playerUnit!.gridX + 2, playerUnit!.gridY + 1, Colors.blue, faction: UnitFaction.player);
    _addUnit(playerUnit!.gridX + 4, playerUnit!.gridY + 4, Colors.red, faction: UnitFaction.enemy);

    turnManager.onUnitTurnStart = (unit) {
      print("Game: Turn started for ${unit.unit.faction}");
      if (unit.unit.faction == UnitFaction.player) {
        focusCell = gridLayer.getCell(unit.x, unit.y);
      } else {
        print("Enemy turn - simple pass for now");
        Future.delayed(const Duration(seconds: 1), () {
          turnManager.endTurn();
        });
      }
    };

    turnManager.onUnitTurnEnd = (unit) {
      print("Game: Turn ended for ${unit.unit.faction}");
      if (focusUnit?.state == unit) {
        focusCell = null;
      }
    };

    turnManager.startBattle();
    updateFog();
  }

  /// 清除对战状态（移除敌方单位、清除焦点/范围）
  void teardownBattle() {
    // 清除焦点
    focusCell = null;
    rangeLayer.clear();

    // 移除非玩家单位
    final toRemove = unitLayer.units.where((u) => u != playerUnit).toList();
    for (final unit in toRemove) {
      turnManager.removeUnit(unit.state);
      unitLayer.removeUnit(unit);
    }

    // 清除回调
    turnManager.onUnitTurnStart = null;
    turnManager.onUnitTurnEnd = null;

    updateFog();
  }

  UnitComponent _addUnit(int x, int y, Color color, {UnitFaction faction = UnitFaction.player}) {
    final unit = BasicSoldier(color: color, faction: faction);
    final unitState = UnitState(unit: unit, x: x, y: y);
    final unitComponent = UnitComponent(state: unitState);
    unitLayer.addUnit(unitComponent);

    turnManager.registerUnit(unitState);
    return unitComponent;
  }

  void updateFog() {
    final visionSources = unitLayer.units
        .where((u) => u.faction == UnitFaction.player)
        .map((u) => (x: u.gridX, y: u.gridY, range: u.state.currentVisionRange))
        .toList();

    gameMap.updateFog(visionSources);
  }

  /// 将棋盘本地坐标通过当前 iso 矩阵投影到世界坐标。
  /// 用于计算相机在过渡动画中应跟踪的世界位置。
  Vector2 projectLocal(Vector2 point) {
    if (isoFactor < 0.001) return point.clone();
    final (m00, m01, m10, m11) = _isoDecorator.matrixComponents;
    return Vector2(
      point.x * m00 + point.y * m01,
      point.x * m10 + point.y * m11,
    );
  }

  // --- 坐标转换覆写（支持插值的等角投影） ---

  @override
  Vector2 parentToLocal(Vector2 point, {Vector2? output}) {
    final projected = super.parentToLocal(point, output: output);
    if (isoFactor < 0.001) return projected;
    return _undoIso(projected);
  }

  @override
  Vector2 toLocal(Vector2 point) {
    if (isoFactor < 0.001) return super.toLocal(point);
    return _undoIso(super.toLocal(point));
  }

  @override
  Vector2 localToParent(Vector2 point, {Vector2? output}) {
    if (isoFactor < 0.001) return super.localToParent(point, output: output);
    return super.localToParent(_applyIso(point), output: output);
  }

  @override
  Vector2 positionOf(Vector2 point) {
    if (isoFactor < 0.001) return super.positionOf(point);
    return super.positionOf(_applyIso(point));
  }

  Vector2 _undoIso(Vector2 v) {
    final (m00, m01, m10, m11) = _isoDecorator.matrixComponents;
    final det = m00 * m11 - m01 * m10;
    final x = (m11 * v.x - m01 * v.y) / det;
    final y = (-m10 * v.x + m00 * v.y) / det;
    v.setValues(x, y);
    return v;
  }

  Vector2 _applyIso(Vector2 v) {
    final (m00, m01, m10, m11) = _isoDecorator.matrixComponents;
    return Vector2(
      v.x * m00 + v.y * m01,
      v.x * m10 + v.y * m11,
    );
  }

  // --- 悬停逻辑 ---
  void onCellHoverEnter(CellComponent cell) {
    if (game.mode != GameMode.battle) return;
    if (_hoveredCell != cell) {
      _hoveredCell = cell;
    }
  }

  void onCellHoverExit(CellComponent cell) {
    if (game.mode != GameMode.battle) return;
    if (_hoveredCell == cell) {
      _hoveredCell = null;
    }
  }

  // --- 点击逻辑 ---

  void onCellTap(CellComponent cell) {
    if (game.mode != GameMode.battle) return;

    final source = focusUnit;
    if (source != null) {
      final skill = source.state.focusSkill;
      final executed = skill.onCellTap(source.state, cell, this);
      if (executed) {
        source.state.recordSkill(skill);
      }
    } else {
      focusCell = (focusCell == cell) ? null : cell;
    }
  }

  void onCellLongPress(CellComponent cell) {
    print('Long press on cell: ${cell.gridX}, ${cell.gridY}');
  }

  // --- 范围层 / 预览单位 ---

  /// 刷新范围层（供 Skill 内部在不改变焦点的情况下手动触发）
  void updateRangeLayer() {
    _updateRangeLayer();
  }

  void _updateRangeLayer() {
    final unit = focusUnit;
    if (unit != null && turnManager.activeUnit == unit.state) {
      final highlights = unit.state.focusSkill.getHighlightPositions(unit.state, this);
      rangeLayer.updateRanges(highlights);
    } else {
      rangeLayer.clear();
    }
  }

  void updatePreviewUnit() {
    _updatePreviewUnit();
  }

  void _updatePreviewUnit() {
    final unit = focusUnit;
    final previewPos = unit?.state.previewPosition;

    if (previewPos != null) {
      if (_previewUnit == null) {
        final projectionState = UnitState(unit: unit!.state.unit, x: previewPos.x, y: previewPos.y);
        _previewUnit = UnitComponent(state: projectionState)..visualOpacity = 0.5;
        unitLayer.add(_previewUnit!);
      } else if (_previewUnit!.gridX != previewPos.x || _previewUnit!.gridY != previewPos.y) {
        unitLayer.remove(_previewUnit!);
        final projectionState = UnitState(unit: unit!.state.unit, x: previewPos.x, y: previewPos.y);
        _previewUnit = UnitComponent(state: projectionState)..visualOpacity = 0.5;
        unitLayer.add(_previewUnit!);
      }
    } else {
      if (_previewUnit != null) {
        unitLayer.remove(_previewUnit!);
        _previewUnit = null;
      }
    }
  }
}
