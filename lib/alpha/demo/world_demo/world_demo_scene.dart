import '../../framework/scene.dart';
import 'world_demo_map.dart';
import 'world_demo_mode.dart';
import 'world_demo_state.dart';

class WorldDemoScene extends Scene {
  WorldDemoScene()
      : super(
          state: WorldDemoState(),
          sceneMap: WorldDemoMap(),
          modes: {'default': WorldDemoMode()},
        );

  @override
  String get name => 'world_demo';

  @override
  Future<void> onEnter() async {
    await switchModeTo('default');
  }
}
