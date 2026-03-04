import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../common/constants.dart';

/// 自包含、自移除的飘字组件。
///
/// 在视口坐标系中生成，向上漂浮 + 淡出后自动移除。
class FloatingTextComponent extends PositionComponent with HasPaint {
  final String text;
  final Color color;
  final double fontSize;

  FloatingTextComponent({
    required this.text,
    required this.color,
    this.fontSize = 14,
    required super.position,
  });

  @override
  Future<void> onLoad() async {
    // 向上漂浮
    add(MoveByEffect(
      Vector2(0, -GameConstants.floatDistance),
      EffectController(duration: GameConstants.floatDuration),
    ));

    // 淡出后自移除
    add(OpacityEffect.to(
      0,
      EffectController(
        startDelay: GameConstants.floatFadeDelay,
        duration: GameConstants.floatDuration - GameConstants.floatFadeDelay,
      ),
      onComplete: removeFromParent,
    ));
  }

  @override
  void render(Canvas canvas) {
    if (opacity <= 0.01) return;

    final shadowColor = const Color(0xFF000000).withValues(alpha: opacity);
    final textColor = color.withValues(alpha: opacity);

    final paragraph = _buildParagraph(textColor, shadowColor);
    canvas.drawParagraph(
      paragraph,
      Offset(-paragraph.maxIntrinsicWidth / 2, -paragraph.height / 2),
    );
  }

  Paragraph _buildParagraph(Color textColor, Color shadowColor) {
    final builder = ParagraphBuilder(ParagraphStyle())
      ..pushStyle(TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(blurRadius: 3, color: shadowColor, offset: const Offset(1, 1))],
      ))
      ..addText(text);
    return builder.build()..layout(ParagraphConstraints(width: fontSize * text.length + 20));
  }
}
