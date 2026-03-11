import 'cell.dart';
import 'chunk_loader.dart';
import 'entity.dart';
import 'map_chunk.dart';
import 'tile_state.dart';

/// 基于区块的地图容器
///
/// 管理已加载的 [MapChunk]，提供世界坐标级别的访问接口。
/// 区块通过 [ChunkLoader] 从 JSON 加载，按需加载/卸载。
class GameMap {
  final Map<(int, int), MapChunk> _chunks = {};
  final ChunkLoader _loader;

  GameMap(this._loader);

  /// 从 JSON 加载一个区块并缓存
  void loadChunk(Map<String, dynamic> chunkJson) {
    final chunk = _loader.load(chunkJson);
    _chunks[(chunk.chunkX, chunk.chunkY)] = chunk;
  }

  /// 卸载指定区块释放内存
  void unloadChunk(int cx, int cy) {
    _chunks.remove((cx, cy));
  }

  /// 检查区块是否已加载
  bool isChunkLoaded(int cx, int cy) {
    return _chunks.containsKey((cx, cy));
  }

  /// 将指定区块序列化为 JSON
  Map<String, dynamic> saveChunk(int cx, int cy) {
    final chunk = _chunks[(cx, cy)];
    if (chunk == null) {
      throw StateError('Chunk ($cx, $cy) not loaded');
    }
    return _loader.save(chunk);
  }

  /// 获取指定世界坐标的地形
  Cell getCell(int worldX, int worldY) {
    final chunk = _resolveChunk(worldX, worldY);
    return chunk.getCell(
      worldX % MapChunk.size,
      worldY % MapChunk.size,
    );
  }

  /// 获取指定世界坐标的实体
  Entity? getEntity(int worldX, int worldY) {
    final chunk = _resolveChunk(worldX, worldY);
    return chunk.getEntity(
      worldX % MapChunk.size,
      worldY % MapChunk.size,
    );
  }

  /// 获取指定世界坐标的状态
  TileState? getState(int worldX, int worldY) {
    final chunk = _resolveChunk(worldX, worldY);
    return chunk.getState(
      worldX % MapChunk.size,
      worldY % MapChunk.size,
    );
  }

  MapChunk _resolveChunk(int worldX, int worldY) {
    final cx = worldX ~/ MapChunk.size;
    final cy = worldY ~/ MapChunk.size;
    final chunk = _chunks[(cx, cy)];
    if (chunk == null) {
      throw StateError(
        'Chunk ($cx, $cy) not loaded for world coordinate ($worldX, $worldY)',
      );
    }
    return chunk;
  }
}
