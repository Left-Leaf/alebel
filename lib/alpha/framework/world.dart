import 'package:flame/components.dart';

import 'camera/viewfinder_3d.dart';

/// 场景地图基类。
///
/// 负责：
/// - 地图的加载与地图信息维护
/// - 各种 Component 的渲染（网格、单位、特效、迷雾等）
///
/// 由 [Scene] 添加到 `camera.viewfinder`，内容通过相机变换渲染。
/// 子类直接调用 [add] 即可将组件放入 viewfinder 坐标系。
abstract class SceneWorld extends Component with ParentIsA<Viewfinder3D> {}
