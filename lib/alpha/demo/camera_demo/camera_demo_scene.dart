import '../../framework/scene.dart';
import 'camera_demo_map.dart';
import 'camera_demo_mode.dart';
import 'camera_demo_state.dart';

class CameraDemoScene extends Scene {
  CameraDemoScene()
      : super(
          state: CameraDemoState(),
          sceneMap: CameraDemoMap(),
          modes: {'default': CameraDemoMode()},
        );

  @override
  String get name => 'camera_demo';

  @override
  Future<void> onEnter() async {
    await switchModeTo('default');
  }
}
