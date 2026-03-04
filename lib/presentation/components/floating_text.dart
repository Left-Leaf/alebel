import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../common/constants.dart';

/// 自包含、自移除的飘字组件。
///
/// 在棋盘本地坐标系中生成（EffectLayer 内），
/// 随棋盘变换一起渲染。可通过 [counterTransform] 反向等角投影，
/// 使文字始终以摄像机俯视角度平面渲染。
class FloatingTextComponent extends PositionComponent with HasPaint {
  final String text;
  final Color color;
  final double fontSize;

  /// 反向等角投影矩阵（column-major 4×4）。
  /// 应用后文字以俯视平面角度渲染，不受等角变换倾斜。
  final Float64List? counterTransform;

  final Vector2 _floatDirection;

  FloatingTextComponent({
    required this.text,
    required this.color,
    this.fontSize = 14,
    this.counterTransform,
    Vector2? floatDirection,
    required super.position,
  }) : _floatDirection = floatDirection ?? Vector2(0, -GameConstants.floatDistance);

  @override
  Future<void> onLoad() async {
    // 向上漂浮（方向已补偿等角投影，在屏幕上呈竖直向上）
    add(MoveByEffect(
      _floatDirection,
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

    final ct = counterTransform;
    if (ct != null) {
      canvas.save();
      canvas.transform(ct);
    }

    final shadowColor = const Color(0xFF000000).withValues(alpha: opacity);
    final textColor = color.withValues(alpha: opacity);

    final paragraph = _buildParagraph(textColor, shadowColor);
    canvas.drawParagraph(
      paragraph,
      Offset(-paragraph.maxIntrinsicWidth / 2, -paragraph.height / 2),
    );

    if (ct != null) {
      canvas.restore();
    }
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
