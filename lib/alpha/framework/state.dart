import 'package:flame/components.dart';

import 'scene.dart';

/// 场景状态基类。
///
/// 存储场景的共享数据，为 [Mode] 的逻辑处理和 [SceneMap] 的渲染提供数据支持。
/// 每个具体场景继承此类定义自己的状态字段。
abstract class SceneState extends Component with ParentIsA<Scene>{}
