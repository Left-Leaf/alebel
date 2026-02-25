import 'package:flame/components.dart';

import '../../game/alebel_game.dart';
import '../components/cell_component.dart';
import '../components/isometric_component.dart';

class BackgroundLayer extends SpriteComponent with HasGameReference<AlebelGame> {
  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('background.jpg');

    final totalWidth = game.gameMap.width * CellComponent.cellSize + AlebelGame.borderWidth * 2;
    final totalHeight = game.gameMap.height * CellComponent.cellSize + AlebelGame.borderWidth * 2;

    // 使用投影后的包围盒尺寸，铺满整个等角投影区域
    final projected = IsometricComponent.projectedBoundingBoxSize(totalWidth, totalHeight);
    size = projected;

    anchor = Anchor.topLeft;
  }
}
