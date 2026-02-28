import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../game/alebel_game.dart';
import '../../game/board_component.dart';
import '../components/cell_component.dart';
import '../components/isometric_component.dart';

class BackgroundLayer extends SpriteComponent with HasGameReference<AlebelGame> {
  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('background.jpg');

    final w = game.board.gameMap.width * CellComponent.cellSize + BoardComponent.borderWidth * 2;
    final h = game.board.gameMap.height * CellComponent.cellSize + BoardComponent.borderWidth * 2;

    // 背景需要覆盖俯视和 iso 两种模式下的完整可视区域。
    //
    // 俯视 (f=0) 包围盒: [0, w] × [0, h]
    // Iso  (f=1) 包围盒: [-cos30·h, cos30·w] × [0, (w+h)·sin30]
    //
    // 取两者并集作为背景范围：
    final xMin = -h * IsometricComponent.cos30;
    final xMax = w; // w > cos30·w (cos30 < 1)
    final yMax = math.max(h, (w + h) * IsometricComponent.sin30);

    position = Vector2(xMin, 0);
    size = Vector2(xMax - xMin, yMax);
    anchor = Anchor.topLeft;
  }
}
