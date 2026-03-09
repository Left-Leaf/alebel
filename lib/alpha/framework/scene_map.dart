import 'package:flame/components.dart';

import 'camera_3d_component.dart';
import 'scene.dart';

/// 场景地图基类。
///
/// 负责：
/// - 地图的加载与地图信息维护
/// - 各种 Component 的渲染（网格、单位、特效、迷雾等）
///
/// 持有 [Camera3DComponent] 作为视角控制的唯一组件，
/// 世界内容作为 [camera] 的子组件添加，视角通过 [camera] 的属性驱动。
abstract class SceneMap<T extends Scene> extends Component with ParentIsA<T> {
  /// 3D 相机组件 — 世界内容添加为其子组件，视角通过其属性驱动。
  final Camera3DComponent camera = Camera3DComponent();

  @override
  Future<void> onLoad() async {
    add(camera);
  }
}
