import 'package:flame/components.dart';

import '../../game/alebel_game.dart';
import '../components/cell_component.dart';

class BackgroundLayer extends SpriteComponent with HasGameReference<AlebelGame> {
  @override
  Future<void> onLoad() async {
    // 加载背景图片，Flame 会自动在 assets/images/ 下查找
    sprite = await game.loadSprite('background.jpg');

    // 设置背景层的大小为整个网格的大小 + 边界
    // 边界宽度 * 2 + 网格总宽度
    final totalWidth = game.gameMap.width * CellComponent.cellSize + AlebelGame.borderWidth * 2;
    final totalHeight = game.gameMap.height * CellComponent.cellSize + AlebelGame.borderWidth * 2;

    size = Vector2(totalWidth, totalHeight);

    // 设置锚点为左上角，与 GridLayer 对齐（GridLayer 的格子通常是基于 (0,0) 开始布局的）
    anchor = Anchor.topLeft;
  }
}
