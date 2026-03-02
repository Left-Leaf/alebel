import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import '../core/battle/battle_scenario.dart';
import '../core/battle/turn_manager.dart';
import '../core/events/event_bus.dart';
import '../core/events/game_event.dart';
import '../core/map/board.dart';
import '../core/map/game_map.dart';
import '../core/unit/unit_state.dart';
import '../models/units/basic_soldier.dart';
import '../models/units/unit_base.dart';
import '../presentation/components/animatable_iso_decorator.dart';
import '../presentation/components/cell_component.dart';
import '../presentation/components/explorer_component.dart';
import '../presentation/components/origin_point.dart';
import '../presentation/components/unit_component.dart';
import '../presentation/layers/fog_layer.dart';
import '../presentation/layers/grid_layer.dart';
import '../presentation/layers/range_layer.dart';
import '../presentation/layers/unit_layer.dart';
import '../presentation/ui/selection_overlay.dart';
import 'alebel_game.dart';
import 'battle_controller.dart';

class BoardComponent extends PositionComponent with HasGameReference<AlebelGame> {
  late final GridLayer gridLayer;
  late final UnitLayer unitLayer;
  late final RangeLayer rangeLayer;
  late final FogLayer fogLayer;
  late GameMap gameMap;
  late final TurnManager turnManager;
  final EventBus eventBus = EventBus();

  late final AnimatableIsoDecorator _isoDecorator;

  /// 探索模式的玩家角色（非 null = 探索模式）
  ExplorerComponent? explorer;

  /// 对战模式中的玩家单位（非 null = 对战模式）
  UnitComponent? playerUnit;

  /// 统一的玩家位置访问（探索 or 对战均可用）
  Position get playerGridPosition {
    if (explorer != null) return (x: explorer!.gridX, y: explorer!.gridY);
    if (playerUnit != null) return (x: playerUnit!.gridX, y: playerUnit!.gridY);
    throw StateError('No player entity');
  }

  /// 战斗控制器（仅在战斗模式下存在）
  BattleController? _battleController;

  // --- 委托属性（供 Skill / SelectionOverlay 等外部使用） ---

  CellComponent? get focusCell => _battleController?.focusCell;

  set focusCell(CellComponent? cell) => _battleController?.focusCell = cell;

  UnitComponent? get focusUnit => _battleController?.focusUnit;

  CellComponent? get hoveredCell => _battleController?.hoveredCell;

  // --- 等角投影因子 ---

  double get isoFactor => _isoDecorator.factor;

  set isoFactor(double value) {
    _isoDecorator.factor = value;
  }

  // 棋盘外围边界宽度（无边界）
  static const double borderWidth = 0;

  @override
  Future<void> onLoad() async {
    _isoDecorator = AnimatableIsoDecorator(factor: 0.0);
    decorator.addLast(_isoDecorator);

    turnManager = TurnManager(eventBus: eventBus);
    gameMap = GameMap.standard(game.cellRegistry);

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

    // 创建探索模式的玩家角色（轻量 ExplorerComponent）
    final playerDef = BasicSoldier(color: Colors.blue, faction: UnitFaction.player);
    explorer = ExplorerComponent(unit: playerDef, gridX: 5, gridY: 5);
    unitLayer.add(explorer!);

    updateFog();
  }

  /// 当前战斗场景（供外部传入触发战斗使用）
  BattleScenario? pendingScenario;

  /// 初始化对战（移除 explorer、创建战斗单位、加载战斗控制器、开始战斗）
  void initBattle() {
    final scenario = pendingScenario;
    pendingScenario = null;

    // 从 explorer 读取位置和定义
    final startX = explorer!.gridX;
    final startY = explorer!.gridY;
    final playerDef = explorer!.unit;

    // 移除 explorer
    unitLayer.remove(explorer!);
    explorer = null;

    // 创建玩家的对战 UnitComponent
    playerUnit = _addUnit(startX, startY, playerDef);

    if (scenario != null) {
      // 按场景配置生成单位
      for (final spawn in scenario.allies) {
        _addUnit(startX + spawn.offset.x, startY + spawn.offset.y, spawn.unit);
      }
      for (final spawn in scenario.enemies) {
        _addUnit(startX + spawn.offset.x, startY + spawn.offset.y, spawn.unit);
      }
    } else {
      // 无场景时的默认敌人（兼容旧调用）
      _addUnit(startX + 4, startY + 4, BasicSoldier(color: Colors.red, faction: UnitFaction.enemy));
    }

    // 加载战斗控制器
    _battleController = BattleController(board: this);
    add(_battleController!);
    _battleController!.setup();

    turnManager.startBattle();
    eventBus.fire(BattleStartEvent());
    updateFog();
  }

  /// 清除对战状态（卸载战斗控制器、移除所有战斗单位、重新创建 explorer）
  void teardownBattle() {
    // 卸载战斗控制器
    _battleController?.cleanup();
    _battleController?.removeFromParent();
    _battleController = null;

    // 记录玩家最终位置和定义
    final endX = playerUnit?.gridX ?? 5;
    final endY = playerUnit?.gridY ?? 5;
    final playerDef =
        playerUnit?.state.unit ?? BasicSoldier(color: Colors.blue, faction: UnitFaction.player);

    // 移除所有对战单位
    for (final unit in unitLayer.units.toList()) {
      turnManager.removeUnit(unit.state);
      unitLayer.removeUnit(unit);
    }
    playerUnit = null;

    // 重新创建 explorer
    explorer = ExplorerComponent(unit: playerDef, gridX: endX, gridY: endY);
    unitLayer.add(explorer!);

    updateFog();
  }

  UnitComponent _addUnit(int x, int y, Unit unitDef) {
    final unitState = UnitState(unit: unitDef, x: x, y: y);
    final unitComponent = UnitComponent(state: unitState);
    unitLayer.addUnit(unitComponent);
    turnManager.registerUnit(unitState);
    return unitComponent;
  }

  void updateFog() {
    final List<({int x, int y, int range})> visionSources;

    if (explorer != null) {
      // 探索模式：只有 explorer 提供视野
      visionSources = [(x: explorer!.gridX, y: explorer!.gridY, range: explorer!.visionRange)];
    } else {
      // 对战模式：所有己方单位提供视野
      visionSources = unitLayer.units
          .where((u) => u.faction == UnitFaction.player)
          .map((u) => (x: u.gridX, y: u.gridY, range: u.state.currentVisionRange))
          .toList();
    }

    gameMap.updateFog(visionSources);
  }

  // --- 委托方法（供 Skill 调用） ---

  void handleUnitDeath(UnitState deadUnit) {
    _battleController?.handleUnitDeath(deadUnit);
  }

  void updateRangeLayer() {
    _battleController?.updateRangeLayer();
  }

  void updatePreviewUnit() {
    _battleController?.updatePreviewUnit();
  }

  /// 将棋盘本地坐标通过当前 iso 矩阵投影到世界坐标。
  /// 用于计算相机在过渡动画中应跟踪的世界位置。
  Vector2 projectLocal(Vector2 point) {
    if (isoFactor < 0.001) return point.clone();
    final (m00, m01, m10, m11) = _isoDecorator.matrixComponents;
    return Vector2(point.x * m00 + point.y * m01, point.x * m10 + point.y * m11);
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
    return Vector2(v.x * m00 + v.y * m01, v.x * m10 + v.y * m11);
  }

  // --- 单元格事件路由（无模式判断，由控制器存在性决定） ---

  void onCellTap(CellComponent cell) {
    _battleController?.onCellTap(cell);
  }

  void onCellHoverEnter(CellComponent cell) {
    _battleController?.onCellHoverEnter(cell);
  }

  void onCellHoverExit(CellComponent cell) {
    _battleController?.onCellHoverExit(cell);
  }

  void onCellLongPress(CellComponent cell) {}
}
