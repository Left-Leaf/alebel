import '../core/map/game_map.dart';

/// 迷雾更新控制器
///
/// 封装视野源计算和迷雾更新逻辑，从 BoardComponent 中分离。
class FogController {
  final GameMap gameMap;
  final List<({int x, int y, int range})> Function() getVisionSources;

  FogController({required this.gameMap, required this.getVisionSources});

  void updateFog() => gameMap.updateFog(getVisionSources());
}
