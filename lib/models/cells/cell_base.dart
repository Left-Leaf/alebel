import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

part 'ground_cell.dart';
part 'wall_cell.dart';
part 'water_cell.dart';
part 'forest_cell.dart';

/// 地图单元格数据模型（静态配置）
sealed class Cell {
  /// 是否阻止视线
  final bool blocksVision;

  /// 是否阻止移动
  final bool blocksMovement;

  /// 单位是否能驻足
  final bool canStand;

  // 调试或序列化用的名称
  final String name;

  const Cell({
    required this.name,
    this.blocksVision = false,
    this.blocksMovement = false,
    this.canStand = true,
  });

  /// 渲染方法，由子类实现具体的绘制逻辑
  void render(Canvas canvas, Size size);
}

/// 精灵图支持混入
/// 子类混入后需实现 [imagePath]，CellRegistry 注册时会自动加载精灵图
mixin SpriteCell on Cell {
  /// 精灵图资源路径（相对于 assets/images/）
  String get imagePath;

  Sprite? _sprite;
  Sprite? get sprite => _sprite;

  /// 从 Flame 图片缓存加载精灵图
  Future<void> loadSprite(Images images) async {
    final image = await images.load(imagePath);
    _sprite = Sprite(image);
  }

  @override
  void render(Canvas canvas, Size size) {
    final s = _sprite;
    if (s != null) {
      s.render(canvas, size: Vector2(size.width, size.height));
    }
  }
}
