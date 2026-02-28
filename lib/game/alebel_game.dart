import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors;

import '../core/battle/turn_manager.dart';
import '../core/map/game_map.dart';
import '../core/unit/unit_state.dart';
import '../models/units/basic_soldier.dart';
import '../models/units/unit_base.dart';
import '../presentation/components/cell_component.dart';
import '../presentation/components/isometric_component.dart';
import '../presentation/components/origin_point.dart';
import '../presentation/components/unit_component.dart';
import '../presentation/layers/background_layer.dart';
import '../presentation/layers/fog_layer.dart';
import '../presentation/layers/grid_layer.dart';
import '../presentation/layers/range_layer.dart';
import '../presentation/layers/unit_layer.dart';
import '../presentation/ui/selection_overlay.dart';
import '../presentation/ui/ui_layer.dart';

class AlebelGame extends FlameGame with ScrollDetector, PanDetector, MouseMovementDetector {
  late final IsometricComponent isoBoard;
  late final GridLayer gridLayer;
  late final UnitLayer unitLayer;
  late final RangeLayer rangeLayer;
  late final FogLayer fogLayer;
  late GameMap gameMap;
  late final TurnManager turnManager;

  /// 投影后的棋盘包围盒尺寸（含边界），用于相机限制
  late final Vector2 _projectedBoardSize;

  // 交互状态
  CellComponent? _hoveredCell;

  CellComponent? get hoveredCell => _hoveredCell;

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

  // 拖拽/点击判定状态
  Vector2? _dragStartScreenPos;
  bool _isDragging = false;

  // 常量
  static const double _dragThreshold = 5.0;

  // 棋盘外围边界宽度（单元格的三倍）
  static const double borderWidth = CellComponent.cellSize;

  @override
  Future<void> onLoad() async {
    turnManager = TurnManager();
    gameMap = GameMap.standard();

    // 计算网格和边界的偏移量
    final boardOffset = Vector2(borderWidth, borderWidth);

    // 原始棋盘总尺寸（投影前）
    final totalWidth = gameMap.width * CellComponent.cellSize + borderWidth * 2;
    final totalHeight = gameMap.height * CellComponent.cellSize + borderWidth * 2;

    // 投影后的包围盒尺寸
    _projectedBoardSize = IsometricComponent.projectedBoundingBoxSize(totalWidth, totalHeight);

    // 创建等角投影容器
    // 偏移使投影后的包围盒左上角对齐世界原点 (0, 0)
    isoBoard = IsometricComponent(position: Vector2(totalHeight * IsometricComponent.cos30, 0));

    // 设置相机锚点，居中于投影后的包围盒
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(_projectedBoardSize.x / 2, _projectedBoardSize.y / 2);

    // 背景层不参与等角投影，直接铺满投影后的包围盒区域
    world.add(BackgroundLayer()..priority = -1);

    // 添加各层到等角投影容器（按渲染顺序，priority 从低到高）
    gridLayer = GridLayer()
      ..position = boardOffset
      ..priority = 1;
    isoBoard.add(gridLayer);

    isoBoard.add(OriginPoint()..priority = 2);

    fogLayer = FogLayer(map: gameMap)
      ..position = boardOffset
      ..priority = 3;
    isoBoard.add(fogLayer);

    isoBoard.add(
      SelectionOverlay()
        ..position = boardOffset
        ..priority = 4,
    );

    rangeLayer = RangeLayer()
      ..position = boardOffset
      ..priority = 5;
    isoBoard.add(rangeLayer);

    unitLayer = UnitLayer()
      ..position = boardOffset
      ..priority = 6;
    isoBoard.add(unitLayer);

    world.add(isoBoard);

    // 添加网格单元格 (作为逻辑实体)
    for (var x = 0; x < gameMap.width; x++) {
      for (var y = 0; y < gameMap.height; y++) {
        final cellState = gameMap.getCell(x, y);
        final cell = CellComponent(state: cellState);
        gridLayer.addCell(cell);
      }
    }

    // 添加测试单位
    _addUnit(2, 2, Colors.blue, faction: UnitFaction.player);
    _addUnit(4, 5, Colors.blue, faction: UnitFaction.player);
    _addUnit(6, 6, Colors.red, faction: UnitFaction.enemy);

    // 添加 UI 层 (添加到视口，使其固定在屏幕上)
    camera.viewport.add(UiLayer());

    turnManager.startBattle();

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
  }

  void _addUnit(int x, int y, Color color, {UnitFaction faction = UnitFaction.player}) {
    final unit = BasicSoldier(color: color, faction: faction);
    final unitState = UnitState(unit: unit, x: x, y: y);
    final unitComponent = UnitComponent(state: unitState);
    unitLayer.addUnit(unitComponent);

    turnManager.registerUnit(unitState);
    updateFog();
  }

  void updateFog() {
    final visionSources = unitLayer.units
        .where((u) => u.faction == UnitFaction.player)
        .map((u) => (x: u.gridX, y: u.gridY, range: u.state.currentVisionRange))
        .toList();

    gameMap.updateFog(visionSources);
  }

  // --- 相机限制逻辑 ---

  double _getMinZoom() {
    if (size.x == 0 || size.y == 0) return 0.1;

    final minZoomX = size.x / _projectedBoardSize.x;
    final minZoomY = size.y / _projectedBoardSize.y;

    return math.max(minZoomX, minZoomY);
  }

  void _clampCamera() {
    final minZoom = _getMinZoom();
    if (camera.viewfinder.zoom < minZoom) {
      camera.viewfinder.zoom = minZoom;
    }

    final viewportWidth = size.x / camera.viewfinder.zoom;
    final viewportHeight = size.y / camera.viewfinder.zoom;

    final minX = viewportWidth / 2;
    final maxX = math.max(minX, _projectedBoardSize.x - viewportWidth / 2);

    final minY = viewportHeight / 2;
    final maxY = math.max(minY, _projectedBoardSize.y - viewportHeight / 2);

    final x = camera.viewfinder.position.x.clamp(minX, maxX);
    final y = camera.viewfinder.position.y.clamp(minY, maxY);

    camera.viewfinder.position = Vector2(x, y);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _clampCamera();
    }
  }

  // --- 悬停逻辑 ---
  void onCellHoverEnter(CellComponent cell) {
    if (_hoveredCell != cell) {
      _hoveredCell = cell;
    }
  }

  void onCellHoverExit(CellComponent cell) {
    if (_hoveredCell == cell) {
      _hoveredCell = null;
    }
  }

  // --- 拖拽逻辑 ---

  @override
  void onPanStart(DragStartInfo info) {
    _dragStartScreenPos = info.eventPosition.widget.clone();
    _isDragging = false;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    final currentScreenPos = info.eventPosition.widget;

    if (!_isDragging) {
      final distance = currentScreenPos.distanceTo(_dragStartScreenPos!);
      if (distance >= _dragThreshold) {
        _isDragging = true;
      }
    }

    if (_isDragging) {
      camera.viewfinder.position -= info.delta.global / camera.viewfinder.zoom;
      _clampCamera();
    }
  }

  @override
  void onPanEnd(DragEndInfo info) {
    _handleInputEnd();
  }

  @override
  void onPanCancel() {
    _handleInputEnd();
  }

  void _handleInputEnd() {
    _isDragging = false;
    _dragStartScreenPos = null;
  }

  // --- 点击逻辑 ---

  void onCellTap(CellComponent cell) {
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

  // --- 缩放逻辑 ---
  @override
  void onScroll(PointerScrollInfo info) {
    final scrollDelta = info.scrollDelta.global.y;
    final currentZoom = camera.viewfinder.zoom;

    double newZoom = currentZoom;
    if (scrollDelta < 0) {
      newZoom = currentZoom * 1.1;
    } else if (scrollDelta > 0) {
      newZoom = currentZoom * 0.9;
    }

    final minZoom = _getMinZoom();
    camera.viewfinder.zoom = newZoom.clamp(minZoom, 10.0);
    _clampCamera();
  }
}
