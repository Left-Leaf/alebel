import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../common/constants.dart';
import '../core/game_mode.dart';
import '../models/cells/cell_base.dart';
import '../models/cells/cell_registry.dart';
import '../presentation/components/cell_component.dart';
import '../presentation/components/isometric_component.dart';
import '../presentation/ui/ui_layer.dart';
import 'board_component.dart';
import 'exploration_controller.dart';

class AlebelGame extends FlameGame
    with ScrollDetector, PanDetector, MouseMovementDetector, HasKeyboardHandlerComponents {
  late final BoardComponent board;
  late final CellRegistry cellRegistry;

  /// 投影后的棋盘包围盒（原点 + 尺寸），用于相机限制
  late Vector2 _projectedBoardOrigin;
  late Vector2 _projectedBoardSize;

  // --- 模式状态 ---
  GameMode _mode = GameMode.exploration;

  GameMode get mode => _mode;

  bool get isTransitioning => _isTransitioning;

  // 过渡动画状态
  bool _isTransitioning = false;
  double _transitionProgress = 0.0;
  static const double _transitionDuration = GameConstants.transitionDuration;

  // 过渡方向
  bool _transitionToBattle = true;

  // 过渡参数
  late Vector2 _pivotLocal; // 视角枢轴点（棋盘本地坐标，通常是玩家 Unit 位置）
  late Vector2 _startPos; // 过渡开始时的相机位置（用于对战→探索 phase1 pan）
  late Vector2 _endWorldPos; // 最终目标世界坐标
  late double _startZoom;
  late double _endZoom;

  // 拖拽/点击判定状态
  Vector2? _dragStartScreenPos;
  bool _isDragging = false;

  // 常量
  static const double _dragThreshold = GameConstants.dragThreshold;

  @override
  Future<void> onLoad() async {
    // 注册 Cell 类型并加载精灵图
    cellRegistry = CellRegistry();
    await cellRegistry.register(this, {
      0: GroundCell(),
      1: WallCell(),
      2: WaterCell(),
      3: const ForestCell(),
    });

    board = BoardComponent();
    world.add(board);

    // 等待 board 加载完成以获取 gameMap 尺寸
    await board.loaded;

    // 计算投影尺寸（初始为俯视图，直接尺寸）
    _recalculateProjectedBounds();

    // 设置相机锚点
    camera.viewfinder.anchor = Anchor.center;

    // 初始相机位置 = 玩家位置世界坐标
    final pos = board.playerGridPosition;
    camera.viewfinder.position = Vector2(
      BoardComponent.borderWidth + (pos.x + 0.5) * CellComponent.cellSize,
      BoardComponent.borderWidth + (pos.y + 0.5) * CellComponent.cellSize,
    );

    // 初始 zoom = 探索近距离视角
    camera.viewfinder.zoom = GameConstants.explorationZoom;

    // 添加 UI 层 (添加到视口，使其固定在屏幕上)
    camera.viewport.add(UiLayer());

    // 添加探索控制器
    world.add(ExplorationController());
  }

  // --- 投影包围盒计算 ---

  /// 计算棋盘在当前 isoFactor 下的投影包围盒（原点 + 尺寸）。
  ///
  /// iso 投影会将棋盘左下角 (0, H) 映射到负 x 区域，
  /// 因此必须同时追踪原点偏移量，相机 clamp 才能正确工作。
  void _recalculateProjectedBounds() {
    final w = board.gameMap.width * CellComponent.cellSize + BoardComponent.borderWidth * 2;
    final h = board.gameMap.height * CellComponent.cellSize + BoardComponent.borderWidth * 2;

    // 将棋盘四角通过当前 iso 矩阵投影到世界坐标
    final c0 = board.projectLocal(Vector2(0, 0));
    final c1 = board.projectLocal(Vector2(w, 0));
    final c2 = board.projectLocal(Vector2(0, h));
    final c3 = board.projectLocal(Vector2(w, h));

    final xs = [c0.x, c1.x, c2.x, c3.x];
    final ys = [c0.y, c1.y, c2.y, c3.y];

    final xMin = xs.reduce(math.min);
    final xMax = xs.reduce(math.max);
    final yMin = ys.reduce(math.min);
    final yMax = ys.reduce(math.max);

    _projectedBoardOrigin = Vector2(xMin, yMin);
    _projectedBoardSize = Vector2(xMax - xMin, yMax - yMin);
  }

  // --- 辅助：计算玩家单位在棋盘本地坐标 ---

  Vector2 _playerLocalPos() {
    final pos = board.playerGridPosition;
    return Vector2(
      BoardComponent.borderWidth + (pos.x + 0.5) * CellComponent.cellSize,
      BoardComponent.borderWidth + (pos.y + 0.5) * CellComponent.cellSize,
    );
  }

  // --- 过渡动画 ---

  /// 探索 → 对战
  ///
  /// Phase 1 (前半): isoFactor 0→1，相机始终跟踪玩家 Unit 经投影后的位置（视角中心稳定）
  /// Phase 2 (后半): isoFactor 保持 1，相机从玩家 Unit(iso) 平移到棋盘中心(iso)，同时缩放
  void startTransitionToBattle() {
    if (_isTransitioning || _mode == GameMode.battle) return;

    _transitionToBattle = true;
    _startZoom = camera.viewfinder.zoom;

    // 枢轴 = 玩家 Unit 棋盘本地坐标
    _pivotLocal = _playerLocalPos();

    // 最终目标 = 玩家 Unit 在 iso 投影下的位置（保持以玩家为中心）
    _endWorldPos = IsometricComponent.project(_pivotLocal.x, _pivotLocal.y);

    // 目标 zoom = 适度缩小，仅比探索视角稍远
    _endZoom = GameConstants.battleZoom;

    _transitionProgress = 0.0;
    _isTransitioning = true;
  }

  /// 对战 → 探索
  ///
  /// Phase 1 (前半): isoFactor 保持 1，相机从当前位置平移到玩家 Unit(iso)，同时缩放
  /// Phase 2 (后半): isoFactor 1→0，相机始终跟踪玩家 Unit 经投影后的位置（视角中心稳定）
  void startTransitionToExploration() {
    if (_isTransitioning || _mode == GameMode.exploration) return;

    _transitionToBattle = false;
    _startPos = camera.viewfinder.position.clone();
    _startZoom = camera.viewfinder.zoom;

    // 枢轴 = 玩家 Unit 棋盘本地坐标
    _pivotLocal = _playerLocalPos();

    // 最终目标 = 玩家 Unit 在俯视视角下的世界坐标（= 本地坐标）
    _endWorldPos = _pivotLocal.clone();
    _endZoom = GameConstants.explorationZoom;

    _transitionProgress = 0.0;
    _isTransitioning = true;
  }

  void _onTransitionComplete() {
    _isTransitioning = false;

    if (_transitionToBattle) {
      board.initBattle();
      _mode = GameMode.battle;
    } else {
      board.teardownBattle();
      _mode = GameMode.exploration;
    }

    _recalculateProjectedBounds();
    clampCamera();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isTransitioning) {
      _transitionProgress = (_transitionProgress + dt / _transitionDuration).clamp(0.0, 1.0);
      final t = _transitionProgress;

      if (_transitionToBattle) {
        _updateTransitionToBattle(t);
      } else {
        _updateTransitionToExploration(t);
      }

      _recalculateProjectedBounds();

      if (t >= 1.0) {
        _onTransitionComplete();
      }
    }
  }

  /// 探索→对战 过渡更新
  void _updateTransitionToBattle(double t) {
    if (t <= 0.5) {
      // Phase 1: iso 变换，相机锁定枢轴点
      final pt = t / 0.5; // 0→1
      board.isoFactor = pt;
      camera.viewfinder.position = board.projectLocal(_pivotLocal);
      camera.viewfinder.zoom = _startZoom;
    } else {
      // Phase 2: 平移 + 缩放
      final pt = (t - 0.5) / 0.5; // 0→1
      board.isoFactor = 1.0;
      final pivotIso = board.projectLocal(_pivotLocal);
      camera.viewfinder.position = _lerpV2(pivotIso, _endWorldPos, pt);
      camera.viewfinder.zoom = _startZoom + (_endZoom - _startZoom) * pt;
    }
  }

  /// 对战→探索 过渡更新
  void _updateTransitionToExploration(double t) {
    if (t <= 0.5) {
      // Phase 1: 平移到枢轴点 + 缩放
      final pt = t / 0.5; // 0→1
      board.isoFactor = 1.0;
      final pivotIso = board.projectLocal(_pivotLocal);
      camera.viewfinder.position = _lerpV2(_startPos, pivotIso, pt);
      camera.viewfinder.zoom = _startZoom + (_endZoom - _startZoom) * pt;
    } else {
      // Phase 2: iso 还原，相机锁定枢轴点
      final pt = (t - 0.5) / 0.5; // 0→1
      board.isoFactor = 1.0 - pt;
      camera.viewfinder.position = board.projectLocal(_pivotLocal);
      camera.viewfinder.zoom = _endZoom;
    }
  }

  static Vector2 _lerpV2(Vector2 a, Vector2 b, double t) {
    return Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  }

  // --- 相机限制逻辑 ---

  double _getMinZoom() {
    if (size.x == 0 || size.y == 0) return 0.1;

    final minZoomX = size.x / _projectedBoardSize.x;
    final minZoomY = size.y / _projectedBoardSize.y;

    return math.max(minZoomX, minZoomY);
  }

  void clampCamera() {
    final minZoom = _getMinZoom();
    if (camera.viewfinder.zoom < minZoom) {
      camera.viewfinder.zoom = minZoom;
    }

    final viewportWidth = size.x / camera.viewfinder.zoom;
    final viewportHeight = size.y / camera.viewfinder.zoom;

    // 使用投影包围盒的原点偏移量来正确计算 clamp 范围
    final minX = _projectedBoardOrigin.x + viewportWidth / 2;
    final maxX = math.max(
      minX,
      _projectedBoardOrigin.x + _projectedBoardSize.x - viewportWidth / 2,
    );

    final minY = _projectedBoardOrigin.y + viewportHeight / 2;
    final maxY = math.max(
      minY,
      _projectedBoardOrigin.y + _projectedBoardSize.y - viewportHeight / 2,
    );

    final x = camera.viewfinder.position.x.clamp(minX, maxX);
    final y = camera.viewfinder.position.y.clamp(minY, maxY);

    camera.viewfinder.position = Vector2(x, y);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      clampCamera();
    }
  }

  // --- 拖拽逻辑 ---

  @override
  void onPanStart(DragStartInfo info) {
    if (_mode == GameMode.exploration || _isTransitioning) return;
    _dragStartScreenPos = info.eventPosition.widget.clone();
    _isDragging = false;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (_mode == GameMode.exploration || _isTransitioning) return;

    final currentScreenPos = info.eventPosition.widget;

    if (!_isDragging) {
      if (_dragStartScreenPos == null) return;
      final distance = currentScreenPos.distanceTo(_dragStartScreenPos!);
      if (distance >= _dragThreshold) {
        _isDragging = true;
      }
    }

    if (_isDragging) {
      camera.viewfinder.position -= info.delta.global / camera.viewfinder.zoom;
      clampCamera();
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

  // --- 缩放逻辑 ---
  @override
  void onScroll(PointerScrollInfo info) {
    if (_isTransitioning || _mode == GameMode.exploration) return;

    final scrollDelta = info.scrollDelta.global.y;
    final currentZoom = camera.viewfinder.zoom;

    double newZoom = currentZoom;
    if (scrollDelta < 0) {
      newZoom = currentZoom * GameConstants.zoomInMultiplier;
    } else if (scrollDelta > 0) {
      newZoom = currentZoom * GameConstants.zoomOutMultiplier;
    }

    final minZoom = _getMinZoom();
    camera.viewfinder.zoom = newZoom.clamp(minZoom, GameConstants.maxZoom);
    clampCamera();
  }
}
