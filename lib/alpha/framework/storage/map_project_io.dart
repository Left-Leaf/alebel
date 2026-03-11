import 'dart:convert';
import 'dart:io';

import '../map/chunk_loader.dart';
import '../map/game_map.dart';
import 'map_project.dart';

/// 地图工程文件操作
///
/// 基于 [dart:io] 的磁盘读写，管理 `maps/<project>/` 目录结构：
/// ```
/// maps/
///   <project_name>/
///     manifest.json
///     chunks/
///       chunk_0_0.json
///       ...
/// ```
class MapProjectIO {
  final Directory baseDir;

  MapProjectIO(this.baseDir);

  /// 获取工程目录
  Directory projectDir(String name) => Directory('${baseDir.path}/$name');

  // ---------------------------------------------------------------------------
  // 工程列表
  // ---------------------------------------------------------------------------

  /// 列出所有工程名称
  Future<List<String>> listProjects() async {
    if (!await baseDir.exists()) return [];
    final entries = await baseDir.list().toList();
    final names = <String>[];
    for (final entry in entries) {
      if (entry is Directory) {
        final manifest = File('${entry.path}/manifest.json');
        if (await manifest.exists()) {
          names.add(entry.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last);
        }
      }
    }
    return names;
  }

  // ---------------------------------------------------------------------------
  // 工程 CRUD
  // ---------------------------------------------------------------------------

  /// 创建空工程
  Future<MapProject> createProject(String name, {int defaultCellId = 0}) async {
    final projectDir = Directory('${baseDir.path}/$name');
    if (await projectDir.exists()) {
      throw StateError('Project "$name" already exists');
    }
    await projectDir.create(recursive: true);
    await Directory('${projectDir.path}/chunks').create();

    final now = DateTime.now();
    final project = MapProject(
      name: name,
      defaultCellId: defaultCellId,
      createdAt: now,
      modifiedAt: now,
    );
    await _writeManifest(projectDir, project);
    return project;
  }

  /// 删除工程（整个目录）
  Future<void> deleteProject(String name) async {
    final projectDir = Directory('${baseDir.path}/$name');
    if (await projectDir.exists()) {
      await projectDir.delete(recursive: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Manifest 读写
  // ---------------------------------------------------------------------------

  /// 加载工程 manifest
  Future<MapProject> loadManifest(String projectName) async {
    final file = File('${baseDir.path}/$projectName/manifest.json');
    final content = await file.readAsString();
    return MapProject.fromJson(
      json.decode(content) as Map<String, dynamic>,
    );
  }

  /// 保存工程 manifest
  Future<void> saveManifest(String projectName, MapProject project) async {
    final projectDir = Directory('${baseDir.path}/$projectName');
    await _writeManifest(projectDir, project);
  }

  // ---------------------------------------------------------------------------
  // Chunk 读写
  // ---------------------------------------------------------------------------

  /// 保存单个区块 JSON
  Future<void> saveChunk(String projectName, Map<String, dynamic> chunkJson) async {
    final cx = chunkJson['x'] as int;
    final cy = chunkJson['y'] as int;
    final file = _chunkFile(projectName, cx, cy);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(chunkJson),
    );
  }

  /// 加载单个区块 JSON
  Future<Map<String, dynamic>> loadChunk(String projectName, int cx, int cy) async {
    final file = _chunkFile(projectName, cx, cy);
    final content = await file.readAsString();
    return json.decode(content) as Map<String, dynamic>;
  }

  /// 删除区块文件
  Future<void> deleteChunkFile(String projectName, int cx, int cy) async {
    final file = _chunkFile(projectName, cx, cy);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ---------------------------------------------------------------------------
  // 整体 GameMap 读写
  // ---------------------------------------------------------------------------

  /// 加载工程的所有区块到 GameMap
  Future<GameMap> loadGameMap(String projectName, ChunkLoader loader) async {
    final project = await loadManifest(projectName);
    final gameMap = GameMap(loader);
    for (final coord in project.chunks) {
      final chunkJson = await loadChunk(projectName, coord.x, coord.y);
      gameMap.loadChunk(chunkJson);
    }
    return gameMap;
  }

  /// 保存 manifest + 所有区块
  Future<void> saveGameMap(
    String projectName,
    MapProject project,
    GameMap gameMap,
    ChunkLoader loader,
  ) async {
    project.modifiedAt = DateTime.now();

    // 保存每个区块
    for (final coord in project.chunks) {
      final chunkJson = gameMap.saveChunk(coord.x, coord.y);
      await saveChunk(projectName, chunkJson);
    }

    // 保存 manifest
    await saveManifest(projectName, project);
  }

  // ---------------------------------------------------------------------------
  // 私有方法
  // ---------------------------------------------------------------------------

  File _chunkFile(String projectName, int cx, int cy) {
    return File('${baseDir.path}/$projectName/chunks/chunk_${cx}_$cy.json');
  }

  Future<void> _writeManifest(Directory projectDir, MapProject project) async {
    final file = File('${projectDir.path}/manifest.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(project.toJson()),
    );
  }
}
