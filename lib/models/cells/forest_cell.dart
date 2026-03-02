part of 'cell_base.dart';

/// ID: 3 - 森林 (阻挡视线，不阻挡移动)
class ForestCell extends Cell with RenderCell {
  const ForestCell()
    : super(
        name: 'Forest',
        blocksVision: true,
      );

  @override
  void render(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.6);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;
    canvas.drawCircle(center, radius, paint);
  }
}
