import 'entity.dart';

/// 实体反序列化函数签名
typedef EntityDeserializer = Entity Function(Map<String, dynamic> json);

/// 实体注册表
///
/// 将字符串类型名映射到 [Entity] 反序列化函数。
class EntityRegistry {
  final Map<String, EntityDeserializer> _deserializers = {};

  void register(String type, EntityDeserializer fromJson) {
    _deserializers[type] = fromJson;
  }

  EntityDeserializer? get(String type) => _deserializers[type];
}

/// 实体工厂
///
/// 通过 [EntityRegistry] 查找反序列化函数，将 JSON 转换为 [Entity]。
class EntityFactory {
  final EntityRegistry registry;

  EntityFactory(this.registry);

  Entity fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null) {
      throw ArgumentError('Entity JSON missing "type" field');
    }
    final deserializer = registry.get(type);
    if (deserializer == null) {
      throw ArgumentError('Unknown entity type: $type');
    }
    return deserializer(json);
  }
}
