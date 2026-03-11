import 'tile_state.dart';

/// 状态反序列化函数签名
typedef StateDeserializer = TileState Function(Map<String, dynamic> json);

/// 状态注册表
///
/// 将字符串类型名映射到 [TileState] 反序列化函数。
class StateRegistry {
  final Map<String, StateDeserializer> _deserializers = {};

  void register(String type, StateDeserializer fromJson) {
    _deserializers[type] = fromJson;
  }

  StateDeserializer? get(String type) => _deserializers[type];
}

/// 状态工厂
///
/// 通过 [StateRegistry] 查找反序列化函数，将 JSON 转换为 [TileState]。
class StateFactory {
  final StateRegistry registry;

  StateFactory(this.registry);

  TileState fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null) {
      throw ArgumentError('TileState JSON missing "type" field');
    }
    final deserializer = registry.get(type);
    if (deserializer == null) {
      throw ArgumentError('Unknown tile state type: $type');
    }
    return deserializer(json);
  }
}
