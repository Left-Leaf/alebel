abstract final class GameConstants {
  // 格子
  static const double cellSize = 50.0;

  // ATB
  static const double maxActionGauge = 1000.0;

  // 动画速度
  static const double moveSpeed = 200.0;
  static const double backtrackSpeed = 300.0;
  static const double fogFadeDuration = 0.25;

  // 迷雾透明度
  static const double fogVisibleOpacity = 0.0;
  static const double fogExploredOpacity = 0.5;
  static const double fogUnknownOpacity = 1.0;

  // 相机
  static const double explorationZoom = 2.0;
  static const double battleZoom = 1.0;
  static const double maxZoom = 10.0;
  static const double transitionDuration = 1.5;
  static const double dragThreshold = 5.0;
  static const double zoomInMultiplier = 1.1;
  static const double zoomOutMultiplier = 0.9;

  // 探索模式
  static const double explorationMoveInterval = 0.15;

  // 地图默认值
  static const int standardMapSize = 40;
  static const int standardMapBorder = 2;
}
