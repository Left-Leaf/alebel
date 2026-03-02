part of 'cell_base.dart';

/// ID: 0 - 普通地面
class GroundCell extends Cell with SpriteCell {
  const GroundCell() : super(name: 'Ground');

  @override
  String get imagePath => 'ground.jpg';
}
