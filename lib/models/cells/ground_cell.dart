import 'dart:ui';
import 'cell_base.dart';

/// ID: 0 - 普通地面
class GroundCell extends Cell {
  const GroundCell() : super(name: 'Ground');

  @override
  void render(Canvas canvas, Size size) {
    // 地面默认可能不需要特殊绘制，或者绘制一个淡淡的底色
    // 这里保持透明，让背景层显示出来，或者画一个调试用的边框
  }
}
