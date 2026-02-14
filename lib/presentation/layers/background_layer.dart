import 'package:flame/components.dart';

import '../../game/alebel_game.dart';

/// 背景层 - 不参与等距变换，直接铺满变换后的包围盒区域。
class BackgroundLayer extends SpriteComponent with HasGameReference<AlebelGame> {
  /// 背景需要覆盖的目标大小（等距变换后的包围盒）
  final Vector2 bgSize;

  BackgroundLayer({required this.bgSize});

  @override
  Future<void> onLoad() async {
    // 加载背景图片，Flame 会自动在 assets/images/ 下查找
    sprite = await game.loadSprite('background.jpg');

    // 背景大小 = 等距变换后的包围盒大小
    size = bgSize;

    // 锚点为左上角，从 (0,0) 开始绘制
    anchor = Anchor.topLeft;
  }
}
