import '../framework/map/cell.dart';
import '../framework/map/chunk_loader.dart';
import '../framework/map/map_chunk.dart';

/// 可编辑地图
///
/// 独立于 [GameMap] 的可变地图容器，专用于编辑器。
/// 支持负坐标区块（无限世界）。
class EditableMap {
  final ChunkLoader _loader;
  final Map<(int, int), MapChunk> _chunks = {};

  EditableMap(this._loader);

  // ---------------------------------------------------------------------------
  // 区块管理
  // ---------------------------------------------------------------------------

  MapChunk createChunk(int cx, int cy, Cell defaultCell) {
    if (_chunks.containsKey((cx, cy))) {
      throw StateError('Chunk ($cx, $cy) already exists');
    }
    final terrain = List.generate(
      MapChunk.size,
      (_) => List.filled(MapChunk.size, defaultCell),
    );
    final chunk = MapChunk(chunkX: cx, chunkY: cy, terrain: terrain);
    _chunks[(cx, cy)] = chunk;
    return chunk;
  }

  void removeChunk(int cx, int cy) {
    if (!_chunks.containsKey((cx, cy))) {
      throw StateError('Chunk ($cx, $cy) not loaded');
    }
    _chunks.remove((cx, cy));
  }

  void loadChunk(Map<String, dynamic> chunkJson) {
    final chunk = _loader.load(chunkJson);
    _chunks[(chunk.chunkX, chunk.chunkY)] = chunk;
  }

  bool isChunkLoaded(int cx, int cy) => _chunks.containsKey((cx, cy));

  MapChunk? getChunk(int cx, int cy) => _chunks[(cx, cy)];

  Iterable<(int, int)> get loadedChunkKeys => _chunks.keys;

  // ---------------------------------------------------------------------------
  // 世界坐标级别操作（支持负坐标）
  // ---------------------------------------------------------------------------

  Cell getCell(int worldX, int worldY) {
    final cx = _chunkCoord(worldX);
    final cy = _chunkCoord(worldY);
    final chunk = _chunks[(cx, cy)];
    if (chunk == null) {
      throw StateError(
        'Chunk ($cx, $cy) not loaded for world ($worldX, $worldY)',
      );
    }
    return chunk.getCell(_localCoord(worldX), _localCoord(worldY));
  }

  void setCell(int worldX, int worldY, Cell cell) {
    final cx = _chunkCoord(worldX);
    final cy = _chunkCoord(worldY);
    final chunk = _chunks[(cx, cy)];
    if (chunk == null) {
      throw StateError(
        'Chunk ($cx, $cy) not loaded for world ($worldX, $worldY)',
      );
    }
    chunk.setCell(_localCoord(worldX), _localCoord(worldY), cell);
  }

  // ---------------------------------------------------------------------------
  // 序列化
  // ---------------------------------------------------------------------------

  Map<String, dynamic> saveChunk(int cx, int cy) {
    final chunk = _chunks[(cx, cy)];
    if (chunk == null) throw StateError('Chunk ($cx, $cy) not loaded');
    return _loader.save(chunk);
  }

  List<Map<String, dynamic>> saveAllChunks() {
    return _chunks.values.map((c) => _loader.save(c)).toList();
  }

  ChunkLoader get loader => _loader;

  // ---------------------------------------------------------------------------
  // 坐标工具（处理负数）
  // ---------------------------------------------------------------------------

  /// 世界格坐标 → 区块坐标（floor 除法）
  static int _chunkCoord(int world) =>
      world >= 0 ? world ~/ MapChunk.size : (world - MapChunk.size + 1) ~/ MapChunk.size;

  /// 世界格坐标 → 区块内局部坐标 [0, size)
  static int _localCoord(int world) {
    final m = world % MapChunk.size;
    return m < 0 ? m + MapChunk.size : m;
  }
}
