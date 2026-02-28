import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/services.dart';

import '../core/game_mode.dart';
import '../presentation/components/cell_component.dart';
import 'alebel_game.dart';
import 'board_component.dart';

class ExplorationController extends Component
    with KeyboardHandler, HasGameReference<AlebelGame> {
  static const double _moveInterval = 0.15;

  double _moveTimer = 0;
  bool _isMoving = false;

  // 当前按下的方向键
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _pressedKeys.clear();
    _pressedKeys.addAll(keysPressed);
    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (game.mode != GameMode.exploration || game.isTransitioning) return;

    _moveTimer += dt;
    if (_moveTimer >= _moveInterval && !_isMoving) {
      final direction = _getDirection();
      if (direction != null) {
        _moveTimer = 0;
        _tryMove(direction.$1, direction.$2);
      }
    }
  }

  (int, int)? _getDirection() {
    int dx = 0;
    int dy = 0;

    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
      dy = -1;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
      dy = 1;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyA) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) {
      dx = -1;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowRight)) {
      dx = 1;
    }

    if (dx == 0 && dy == 0) return null;
    return (dx, dy);
  }

  void _tryMove(int dx, int dy) {
    final pu = game.board.playerUnit;
    if (pu == null) return;

    final newX = pu.state.x + dx;
    final newY = pu.state.y + dy;

    // 边界检查
    if (newX < 0 || newX >= game.board.gameMap.width ||
        newY < 0 || newY >= game.board.gameMap.height) {
      return;
    }

    // 地形检查
    final cellState = game.board.gameMap.getCell(newX, newY);
    if (cellState.blocksMovement) return;

    // 通过 → 更新位置并播放短动画
    _isMoving = true;
    pu.state.x = newX;
    pu.state.y = newY;

    final targetPos = Vector2(
      (newX + 0.5) * CellComponent.cellSize,
      (newY + 0.5) * CellComponent.cellSize,
    );

    final completer = Completer<void>();
    game.board.add(
      MoveToEffect(
        targetPos,
        EffectController(duration: 0.1),
        target: pu,
        onComplete: () {
          game.board.updateFog();
          _isMoving = false;
          completer.complete();
        },
      ),
    );

    // 立即更新相机跟随
    _updateCameraFollow();
  }

  void _updateCameraFollow() {
    final pu = game.board.playerUnit;
    if (pu == null) return;
    game.camera.viewfinder.position = Vector2(
      BoardComponent.borderWidth + (pu.state.x + 0.5) * CellComponent.cellSize,
      BoardComponent.borderWidth + (pu.state.y + 0.5) * CellComponent.cellSize,
    );
    game.clampCamera();
  }
}
