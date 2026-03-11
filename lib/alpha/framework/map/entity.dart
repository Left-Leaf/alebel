/// 实体基类
///
/// 代表地图上的可交互对象（NPC、宝箱等）。
/// 实体是稀疏数据，只有少数格子包含实体。
abstract class Entity {
  const Entity();

  String get type;
  Map<String, dynamic> toJson();
}
