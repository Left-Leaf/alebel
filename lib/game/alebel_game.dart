import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors;

import '../presentation/layers/background_layer.dart';
import '../presentation/components/cell_component.dart';
import '../presentation/layers/fog_layer.dart';
import '../presentation/layers/grid_layer.dart';
import '../presentation/components/origin_point.dart';
import '../presentation/layers/range_layer.dart';
import '../presentation/ui/selection_overlay.dart';
import '../presentation/ui/ui_layer.dart';
import '../presentation/components/unit_component.dart';
import '../presentation/layers/unit_layer.dart';
import '../core/map/game_map.dart';
import '../core/unit/unit_state.dart';
import '../models/units/unit_base.dart';
import '../models/units/basic_soldier.dart';
import '../core/battle/turn_manager.dart';

class AlebelGame extends FlameGame with ScrollDetector, PanDetector, MouseMovementDetector {
  late final GridLayer gridLayer;
  late final UnitLayer unitLayer;
  late final RangeLayer rangeLayer;
  late final FogLayer fogLayer;
  late GameMap gameMap;
  late final TurnManager turnManager;

  // 交互状态
  CellComponent? _hoveredCell;

  CellComponent? get hoveredCell => _hoveredCell;

  // 选中的 Unit
  UnitComponent? get selectedUnit {
    if (_selectedCell == null) return null;
    return unitLayer.getUnitAt(_selectedCell!.gridX, _selectedCell!.gridY);
  }

  CellComponent? _selectedCell;

  CellComponent? get selectedCell => _selectedCell;
  
  // 预览/投影单位 (Ghost Unit)
  UnitComponent? _previewUnit;

  // 拖拽/点击判定状态
  Vector2? _dragStartScreenPos;
  bool _isDragging = false;
  // bool _isAttackMode = false; // 攻击模式状态
  // CellComponent? _pointerDownCell;

  // bool get isAttackMode => _isAttackMode;

  // 常量
  static const double _dragThreshold = 5.0;

  // 棋盘外围边界宽度（单元格的三倍）
  static const double borderWidth = CellComponent.cellSize * 3;

  @override
  Future<void> onLoad() async {
    turnManager = TurnManager();
    gameMap = GameMap.standard();

    // 计算网格和边界的偏移量
    final boardOffset = Vector2(borderWidth, borderWidth);

    // 设置相机锚点
    camera.viewfinder.anchor = Anchor.center;
    // 将相机中心移动到棋盘中心（包括边界）
    // 棋盘中心 = 边界偏移 + 网格中心
    camera.viewfinder.position =
        boardOffset +
        Vector2(
          gameMap.width * CellComponent.cellSize / 2,
          gameMap.height * CellComponent.cellSize / 2,
        );

    // 添加背景层（最底层）
    // 背景层覆盖整个区域（边界 + 网格）
    // 背景层不需要偏移，因为它从 (0,0) 开始绘制，大小包含边界
    world.add(BackgroundLayer());

    // 添加网格层
    gridLayer = GridLayer()..position = boardOffset;
    world.add(gridLayer);

    // 添加原点标记 (为了调试方便，放在网格之上，选中层之下)
    world.add(OriginPoint());
    // 添加迷雾层 (位于移动范围层下方)
    fogLayer = FogLayer(map: gameMap)..position = boardOffset;
    world.add(fogLayer);

    // 添加选中层
    // 选中层需要与网格层对齐，所以也需要设置偏移
    world.add(SelectionOverlay()..position = boardOffset);

    // 添加范围层
    rangeLayer = RangeLayer()..position = boardOffset;
    world.add(rangeLayer);

    // 添加单位层
    // 单位层需要与网格层对齐
    unitLayer = UnitLayer()..position = boardOffset;
    world.add(unitLayer);

    // 添加网格单元格 (作为逻辑实体)
    for (var x = 0; x < gameMap.width; x++) {
      for (var y = 0; y < gameMap.height; y++) {
        final cellState = gameMap.getCell(x, y);
        final cell = CellComponent(state: cellState);
        // world.add(cell); // CellComponent 是纯数据/逻辑，不再直接添加到世界
        gridLayer.addCell(cell);
      }
    }

    // 添加测试单位
    // 玩家单位 (蓝色)
    _addUnit(2, 2, Colors.blue, faction: UnitFaction.player);
    _addUnit(4, 5, Colors.blue, faction: UnitFaction.player);

    // 敌方单位 (红色)
    _addUnit(6, 6, Colors.red, faction: UnitFaction.enemy);

    // 添加 UI 层 (添加到视口，使其固定在屏幕上)
    camera.viewport.add(UiLayer());

    turnManager.startBattle();
    
    // Register events
    turnManager.onUnitTurnStart = (unit) {
      print("Game: Turn started for ${unit.unit.faction}");
      if (unit.unit.faction == UnitFaction.player) {
         // Auto-select active unit
         final component = unitLayer.getUnitAt(unit.x, unit.y);
         if (component != null) {
           selectUnit(component);
         }
      } else {
        // AI Turn (TODO)
        print("Enemy turn - simple pass for now");
        // Simulate enemy action delay
        Future.delayed(const Duration(seconds: 1), () {
           turnManager.endTurn();
        });
      }
    };
    
    turnManager.onUnitTurnEnd = (unit) {
      print("Game: Turn ended for ${unit.unit.faction}");
      if (selectedUnit?.state == unit) {
        deselectUnit();
      }
    };
  }

  void _addUnit(int x, int y, Color color, {UnitFaction faction = UnitFaction.player}) {
    final unit = BasicSoldier(color: color, faction: faction);
    final unitState = UnitState(unit: unit, x: x, y: y);
    final unitComponent = UnitComponent(state: unitState);
    unitLayer.addUnit(unitComponent);
    // world.add(unit); // UnitComponent 是纯数据，不再直接添加到世界
    
    turnManager.registerUnit(unitState);

    // 更新迷雾
    updateFog();
  }

  void updateFog() {
    // 只获取玩家阵营的视野
    final visionSources = unitLayer.units
        .where((u) => u.faction == UnitFaction.player)
        .map((u) => (x: u.gridX, y: u.gridY, range: u.state.currentVisionRange))
        .toList();

    gameMap.updateFog(visionSources);
  }

  // --- 相机限制逻辑 ---

  // 计算最小缩放比例，使得视口完全被世界包含（无黑边）
  double _getMinZoom() {
    final totalWidth = gameMap.width * CellComponent.cellSize + borderWidth * 2;
    final totalHeight = gameMap.height * CellComponent.cellSize + borderWidth * 2;

    // 如果窗口还未准备好（size为0），返回一个默认值
    if (size.x == 0 || size.y == 0) return 0.1;

    // 视口大小 = 屏幕大小 / zoom
    // 我们要求：视口大小 <= 世界大小
    // 即：屏幕大小 / zoom <= 世界大小
    // => zoom >= 屏幕大小 / 世界大小

    final minZoomX = size.x / totalWidth;
    final minZoomY = size.y / totalHeight;

    // 取最大值，保证两个维度都满足条件（即整个屏幕都被世界填满）
    return math.max(minZoomX, minZoomY);
  }

  void _clampCamera() {
    // 1. 首先确保缩放比例不小于最小值
    final minZoom = _getMinZoom();
    // 如果当前zoom小于minZoom，强制设为minZoom
    if (camera.viewfinder.zoom < minZoom) {
      camera.viewfinder.zoom = minZoom;
    }

    // 游戏世界总尺寸
    final totalWidth = gameMap.width * CellComponent.cellSize + borderWidth * 2;
    final totalHeight = gameMap.height * CellComponent.cellSize + borderWidth * 2;

    // 当前视口在世界坐标中的尺寸
    final viewportWidth = size.x / camera.viewfinder.zoom;
    final viewportHeight = size.y / camera.viewfinder.zoom;

    // 计算相机中心允许移动的范围
    // 相机中心最左边位置：视口宽度的一半
    // 相机中心最右边位置：世界宽度 - 视口宽度的一半
    // 由于我们已经保证了 zoom >= minZoom，所以 viewportWidth <= totalWidth 必定成立
    // 因此 minX <= maxX 必定成立

    // 注意：使用 roundToDouble 或增加微小容差来避免浮点数精度导致的 min > max 问题
    final minX = viewportWidth / 2;
    final maxX = math.max(minX, totalWidth - viewportWidth / 2);

    final minY = viewportHeight / 2;
    final maxY = math.max(minY, totalHeight - viewportHeight / 2);

    // 执行限制
    final x = camera.viewfinder.position.x.clamp(minX, maxX);
    final y = camera.viewfinder.position.y.clamp(minY, maxY);

    camera.viewfinder.position = Vector2(x, y);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // 当窗口大小改变时，重新计算最小缩放并应用限制
    // 这会自动处理“如果已经处于最小缩放，窗口改变时应自动调整zoom以保持填满”的需求
    if (isLoaded) {
      _clampCamera();
    }
  }

  CellComponent? _getCellUnderMouse(Vector2 screenPosition) {
    // 1. 获取世界坐标
    final worldPosition = camera.viewfinder.transform.globalToLocal(screenPosition);

    // 2. 转换为 GridLayer 本地坐标 (减去边界偏移)
    final localPosition = worldPosition - Vector2(borderWidth, borderWidth);

    // 3. 计算网格坐标
    final gridX = (localPosition.x / CellComponent.cellSize).floor();
    final gridY = (localPosition.y / CellComponent.cellSize).floor();

    return gridLayer.getCell(gridX, gridY);
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
    // _pointerDownCell = _getCellUnderMouse(info.eventPosition.widget);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    final currentScreenPos = info.eventPosition.widget;

    // 1. 判定是否构成拖拽
    if (!_isDragging) {
      final distance = currentScreenPos.distanceTo(_dragStartScreenPos!);
      if (distance >= _dragThreshold) {
        _isDragging = true;
      }
    }

    // 2. 如果正在拖拽，执行平移
    if (_isDragging) {
      // 相机移动方向与拖拽方向相反
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
    // 重置状态
    _isDragging = false;
    // _pointerDownCell = null;
    _dragStartScreenPos = null;
  }

  void onCellTap(CellComponent cell) {
    print('Tap on cell: ${cell.gridX}, ${cell.gridY}');
    // final targetPos = (x: cell.gridX, y: cell.gridY);

    // 1. 检查点击位置是否有单位
    final target = unitLayer.getUnitAt(cell.gridX, cell.gridY);
    final unit = selectedUnit;

    if (target != null) {
      // 检查单位可见性
      // 如果目标在迷雾中（且是敌方），则视为不可见（当做空地处理）
      // 玩家单位总是可见
      final cellState = gameMap.getCell(cell.gridX, cell.gridY);
      bool isVisible = true;
      if (target.faction != UnitFaction.player && !cellState.isCenterVisible) {
        isVisible = false;
      }

      if (isVisible) {
        // 点击了单位
        if (target.faction == UnitFaction.player) {
          // 点击己方单位
          if (unit == target) {
            // 如果点击的是已选中的单位，取消选中
            deselectUnit();
          } else {
            // 选中新单位
            selectUnit(target);
          }
        } else {
          // 点击其他单位（敌方/中立）
          // 如果有选中单位且在攻击范围等，由 Skill 处理
          // 但这里 Skill.onCellTap 是处理“点击空地”或“点击目标”的逻辑
          // 目前 Skill 接口只有一个 onCellTap，它接收的是 CellComponent
          // 可以在 onCellTap 内部再判断是否有单位
          
          // 如果当前有选中单位，优先交给 Skill 处理（例如攻击）
          if (unit != null) {
             unit.state.currentSkill.onCellTap(unit.state, cell, this);
          } else {
            // 否则选中该单位（查看信息）
            // deselectUnit();
            selectUnit(target); // 可以选中敌方查看信息
          }
        }
        return; // 处理完毕
      }
    } 
    
    // 点击了空地 (或者不可见的单位)
    if (unit != null) {
      // 交给当前 Skill 处理
      unit.state.currentSkill.onCellTap(unit.state, cell, this);
    } else {
      // 无选中单位 -> 处理格子选中
      if (_selectedCell == cell) {
        deselectCell();
      } else {
        selectCell(cell);
      }
    }
  }

  void onCellLongPress(CellComponent cell) {
    print('Long press on cell: ${cell.gridX}, ${cell.gridY}');
    // TODO: Show info panel logic here
  }

  void selectUnit(UnitComponent unit) {
    // 如果已经有选中的（切换选中），先清理
    if (selectedUnit != null) {
      deselectUnit();
    }

    print('Selected unit at ${unit.gridX}, ${unit.gridY}');

    // 选中单位所在的格子
    final cell = gridLayer.getCell(unit.gridX, unit.gridY);
    if (cell != null) {
      selectCell(cell);
    }

    updateRangeLayer();
  }

  void deselectUnit() {
    final unit = selectedUnit;
    if (unit != null) {
      unit.state.previewPosition = null;
    }
    _updatePreviewUnit();
    rangeLayer.clear();
    
    deselectCell();
  }

  void updateRangeLayer() {
    final unit = selectedUnit;
    if (unit != null) {
      // Only show range if it's the unit's turn
      if (turnManager.activeUnit == unit.state) {
        final highlights = unit.state.currentSkill.getHighlightPositions(unit.state, this);
        rangeLayer.updateRanges(highlights);
      } else {
        rangeLayer.clear();
      }
      _updatePreviewUnit();
    } else {
      rangeLayer.clear();
      _updatePreviewUnit();
    }
  }

  void _updatePreviewUnit() {
    final unit = selectedUnit;
    final previewPos = unit?.state.previewPosition;

    if (previewPos != null) {
      // Should show preview
      if (_previewUnit == null) {
        // Create new
        final projectionState = UnitState(unit: unit!.state.unit, x: previewPos.x, y: previewPos.y);
        _previewUnit = UnitComponent(state: projectionState)..visualOpacity = 0.5;
        unitLayer.add(_previewUnit!);
      } else {
        // Update position if needed
        if (_previewUnit!.gridX != previewPos.x || _previewUnit!.gridY != previewPos.y) {
           // We might need a better way to move it, but for now recreating or forcing update is ok.
           // UnitComponent usually updates based on state, but here state is new.
           unitLayer.remove(_previewUnit!);
           final projectionState = UnitState(unit: unit!.state.unit, x: previewPos.x, y: previewPos.y);
           _previewUnit = UnitComponent(state: projectionState)..visualOpacity = 0.5;
           unitLayer.add(_previewUnit!);
        }
      }
    } else {
      // Should remove preview
      if (_previewUnit != null) {
        unitLayer.remove(_previewUnit!);
        _previewUnit = null;
      }
    }
  }

  void selectCell(CellComponent cell) {
    _selectedCell?.isSelected = false;
    _selectedCell = cell;
    _selectedCell?.isSelected = true;
  }

  void deselectCell() {
    _selectedCell?.isSelected = false;
    _selectedCell = null;
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
