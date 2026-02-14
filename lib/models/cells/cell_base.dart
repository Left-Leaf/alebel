import 'package:flutter/material.dart';

/// 地图单元格数据模型（静态配置）
abstract class Cell {
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
