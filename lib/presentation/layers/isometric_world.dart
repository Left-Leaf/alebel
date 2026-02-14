import 'dart:math' as math;

import 'package:flame/components.dart';

/// 等距透视包装组件
///
/// 通过嵌套两层组件实现正确的等距投影：
///   外层 (IsometricWorld): 仅做 Y 轴压缩 scale=(1, yScale)
///   内层 (_rotatedContent): 仅做 -45° 旋转
///
/// 渲染时变换顺序为：先旋转 → 再 Y 缩放，
/// 这样正方形格子会先变成正菱形，再被纵向压扁，
/// 产生经典的 2:1 等距视角效果。
class IsometricWorld extends PositionComponent {
  /// Y 轴缩放比例（模拟俯视角压缩）
  static const double yScale = 0.5;

  /// 内层旋转容器，所有游戏层都作为其子组件
  final PositionComponent _rotatedContent;

  IsometricWorld({
    required double boardWidth,
    required double boardHeight,
    required Vector2 worldCenter,
  })  : _rotatedContent = PositionComponent(
          anchor: Anchor.center,
          // 内层居中于外层的内容空间
          position: _computeRotatedBBSize(boardWidth, boardHeight) / 2,
          size: Vector2(boardWidth, boardHeight),
          angle: -math.pi / 4,
        ),
        super(
          anchor: Anchor.center,
          position: worldCenter,
          // 外层尺寸 = 旋转后的包围盒（未 Y 缩放）
          size: _computeRotatedBBSize(boardWidth, boardHeight),
          // 外层仅做 Y 轴压缩
          scale: Vector2(1.0, yScale),
        ) {
    // 将旋转容器作为外层的直接子组件（绕过 add 重写）
    super.add(_rotatedContent);
  }

  /// 重写 add，所有外部添加的子组件都进入内层旋转容器
  @override
  void add(Component component) {
    _rotatedContent.add(component);
  }

  /// 将世界坐标转换为内容本地坐标（逆等距变换）。
  /// 依次通过外层逆缩放 → 内层逆旋转。
  Vector2 worldToLocal(Vector2 worldPoint) {
    final outerLocal = transform.globalToLocal(worldPoint);
    return _rotatedContent.transform.globalToLocal(outerLocal);
  }

  /// 计算旋转后（未 Y 缩放）的轴对齐包围盒大小。
  /// 即原始矩形旋转 45° 后的外接矩形。
  static Vector2 _computeRotatedBBSize(double w, double h) {
    final cos45 = math.cos(math.pi / 4);
    final sin45 = math.sin(math.pi / 4);
    return Vector2(
      cos45 * w + sin45 * h,
      sin45 * w + cos45 * h,
    );
  }

  /// 计算等距变换后在世界坐标中的最终包围盒大小
  /// （旋转 + Y 缩放后的结果）。
  static Vector2 computeBoundingBoxSize(
      double boardWidth, double boardHeight) {
    final rotBB = _computeRotatedBBSize(boardWidth, boardHeight);
    return Vector2(rotBB.x, rotBB.y * yScale);
  }
}
