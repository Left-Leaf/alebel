part of 'cell_base.dart';

/// ID: 2 - 水域 (阻挡移动，不阻挡视线)
class WaterCell extends Cell with SpriteCell {
  const WaterCell()
    : super(
        name: 'Water',
        blocksMovement: true,
        canStand: false,
      );

  @override
  String get imagePath => 'water.jpg';
}
