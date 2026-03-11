import 'cell.dart';
import 'cell_registry.dart';
import 'entity.dart';
import 'entity_factory.dart';
import 'map_chunk.dart';
import 'state_factory.dart';
import 'tile_state.dart';

/// 区块加载器
///
/// 将 JSON 数据转换为 [MapChunk]，通过三个子系统分别处理：
/// - [CellRegistry]：int → Cell（地形层）
/// - [EntityFactory]：JSON → Entity（实体层）
/// - [StateFactory]：JSON → TileState（状态层）
class ChunkLoader {
  final CellRegistry cellRegistry;
  final EntityFactory entityFactory;
  final StateFactory stateFactory;

  ChunkLoader({
    required this.cellRegistry,
    required this.entityFactory,
    required this.stateFactory,
  });

  /// 从 JSON 加载区块
  ///
  /// JSON 格式：
  /// ```json
  /// {
  ///   "x": 5,
  ///   "y": 3,
  ///   "terrain": [[0, 0, 1, ...], ...],
  ///   "entities": [{"x": 3, "y": 5, "data": {"type": "chest", ...}}, ...],
  ///   "states": [{"x": 3, "y": 5, "data": {"type": "fire", ...}}, ...]
  /// }
  /// ```
  MapChunk load(Map<String, dynamic> json) {
    final chunkX = json['x'] as int;
    final chunkY = json['y'] as int;

    // 解析地形矩阵
    final terrainJson = json['terrain'] as List<dynamic>;
    final terrain = _parseTerrain(terrainJson);

    // 解析实体列表
    final entitiesJson = json['entities'] as List<dynamic>?;
    final entities = _parseEntities(entitiesJson);

    // 解析状态列表
    final statesJson = json['states'] as List<dynamic>?;
    final states = _parseStates(statesJson);

    return MapChunk(
      chunkX: chunkX,
      chunkY: chunkY,
      terrain: terrain,
      entities: entities,
      states: states,
    );
  }

  /// 将区块序列化为 JSON
  ///
  /// 输出格式与 [load] 输入格式一致，可直接持久化。
  Map<String, dynamic> save(MapChunk chunk) {
    final terrainJson = _serializeTerrain(chunk.terrain);
    final entitiesJson = _serializeEntities(chunk.entities);
    final statesJson = _serializeStates(chunk.states);

    return {
      'x': chunk.chunkX,
      'y': chunk.chunkY,
      'terrain': terrainJson,
      if (entitiesJson.isNotEmpty) 'entities': entitiesJson,
      if (statesJson.isNotEmpty) 'states': statesJson,
    };
  }

  List<List<int>> _serializeTerrain(List<List<Cell>> terrain) {
    return terrain.map<List<int>>((row) {
      return row.map<int>((cell) => cell.id).toList();
    }).toList();
  }

  List<Map<String, dynamic>> _serializeEntities(
    Map<(int, int), Entity> entities,
  ) {
    return entities.entries.map((entry) {
      final (x, y) = entry.key;
      return {
        'x': x,
        'y': y,
        'data': entry.value.toJson(),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _serializeStates(
    Map<(int, int), TileState> states,
  ) {
    return states.entries.map((entry) {
      final (x, y) = entry.key;
      return {
        'x': x,
        'y': y,
        'data': entry.value.toJson(),
      };
    }).toList();
  }

  List<List<Cell>> _parseTerrain(List<dynamic> terrainJson) {
    return terrainJson.map<List<Cell>>((row) {
      final rowList = row as List<dynamic>;
      return rowList.map<Cell>((id) => cellRegistry.get(id as int)).toList();
    }).toList();
  }

  Map<(int, int), Entity> _parseEntities(List<dynamic>? entitiesJson) {
    if (entitiesJson == null || entitiesJson.isEmpty) return {};
    final result = <(int, int), Entity>{};
    for (final entry in entitiesJson) {
      final map = entry as Map<String, dynamic>;
      final x = map['x'] as int;
      final y = map['y'] as int;
      final data = map['data'] as Map<String, dynamic>;
      result[(x, y)] = entityFactory.fromJson(data);
    }
    return result;
  }

  Map<(int, int), TileState> _parseStates(List<dynamic>? statesJson) {
    if (statesJson == null || statesJson.isEmpty) return {};
    final result = <(int, int), TileState>{};
    for (final entry in statesJson) {
      final map = entry as Map<String, dynamic>;
      final x = map['x'] as int;
      final y = map['y'] as int;
      final data = map['data'] as Map<String, dynamic>;
      result[(x, y)] = stateFactory.fromJson(data);
    }
    return result;
  }
}
