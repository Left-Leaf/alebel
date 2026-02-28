part of 'cell_base.dart';

/// ID: 1 - 墙壁 (阻挡视线和移动)
class WallCell extends Cell with SpriteCell {
  WallCell()
    : super(
        name: 'Wall',
        blocksVision: true,
        blocksMovement: true,
        canStand: false,
      );

  @override
  String get imagePath => 'wall.jpg';
}
