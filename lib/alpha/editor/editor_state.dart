import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../framework/map/cell.dart';
import '../framework/map/cell_registry.dart';
import '../framework/map/chunk_loader.dart';
import '../framework/map/map_chunk.dart';
import '../framework/storage/map_project.dart';
import '../framework/storage/map_project_io.dart';
import 'editable_map.dart';

/// 编辑器状态
///
/// 纯 Dart 层状态管理，通过 [ChangeNotifier] 驱动 Flutter UI 刷新。
/// Flame 侧通过引用读取数据，不持有此对象为子组件。
class EditorState extends ChangeNotifier {
  /// 可用地形类型
  final CellRegistry cellRegistry;

  /// Cell ID -> 回退颜色（材质图未加载时使用）
  final Map<int, ui.Color> cellColors;

  /// Cell ID -> 材质图路径（Flame 相对路径）
  final Map<int, String> cellImagePaths;

  /// 区块加载器
  final ChunkLoader chunkLoader;

  /// 工程文件 IO（可通过 [setMapsDirectory] 动态切换）
  MapProjectIO? projectIO;

  /// 渲染格子大小
  final double cellSize;

  /// Cell ID -> 已加载的材质图（由 EditorMapGame 填充）
  final Map<int, ui.Image> cellImages = {};

  /// 当前编辑的可变地图
  EditableMap? editableMap;

  /// 当前工程元数据
  MapProject? _project;

  /// 当前工程名
  String? _projectName;

  /// 当前选中的画笔
  Cell? _selectedCell;

  /// 是否有未保存修改
  bool _isDirty = false;

  /// 鼠标悬停的区块坐标 (chunkX, chunkY)，包含未加载位置
  (int, int)? _hoveredChunk;

  /// 鼠标点击选中的世界坐标 (worldX, worldY)
  (int, int)? _selectedCellPos;

  EditorState({
    required this.cellRegistry,
    required this.cellColors,
    required this.cellImagePaths,
    required this.chunkLoader,
    this.projectIO,
    this.cellSize = 30,
  });

  // ---------------------------------------------------------------------------
  // 属性
  // ---------------------------------------------------------------------------

  MapProject? get project => _project;
  String? get projectName => _projectName;
  Cell? get selectedCell => _selectedCell;
  bool get isDirty => _isDirty;
  (int, int)? get hoveredChunk => _hoveredChunk;
  (int, int)? get selectedCellPos => _selectedCellPos;

  set selectedCell(Cell? cell) {
    _selectedCell = cell;
    notifyListeners();
  }

  set hoveredChunk((int, int)? chunk) {
    if (_hoveredChunk == chunk) return;
    _hoveredChunk = chunk;
    notifyListeners();
  }

  set selectedCellPos((int, int)? pos) {
    if (_selectedCellPos == pos) return;
    _selectedCellPos = pos;
    notifyListeners();
  }

  /// 悬停位置的区块是否已加载
  bool get isHoveredChunkLoaded {
    final h = _hoveredChunk;
    if (h == null) return false;
    return editableMap?.isChunkLoaded(h.$1, h.$2) ?? false;
  }

  /// 获取选中位置的 Cell 信息（状态栏显示用）
  Cell? get selectedCellType {
    final pos = _selectedCellPos;
    final map = editableMap;
    if (pos == null || map == null) return null;
    try {
      return map.getCell(pos.$1, pos.$2);
    } catch (_) {
      return null;
    }
  }

  /// 默认 Cell ID（空白地块）
  static const int defaultCellId = 0;

  /// 默认 Cell
  Cell get defaultCell {
    final id = _project?.defaultCellId ?? defaultCellId;
    return cellRegistry.get(id);
  }

  /// 所有已加载区块坐标
  Iterable<(int, int)> get loadedChunkKeys =>
      editableMap?.loadedChunkKeys ?? const [];

  /// 计算已加载区块四周的未加载邻居位置（可扩展位置）
  Set<(int, int)> get expandableChunkPositions {
    final map = editableMap;
    if (map == null) return const {};

    final result = <(int, int)>{};
    for (final (cx, cy) in map.loadedChunkKeys) {
      for (final (dx, dy) in [(0, -1), (0, 1), (-1, 0), (1, 0)]) {
        final nx = cx + dx;
        final ny = cy + dy;
        if (!map.isChunkLoaded(nx, ny)) {
          result.add((nx, ny));
        }
      }
    }
    return result;
  }

  /// 区块像素尺寸
  double get chunkPixelSize => MapChunk.size * cellSize;

  /// 当前地图目录路径
  String? get mapsDirectoryPath => projectIO?.baseDir.path;

  /// 是否已选择地图目录
  bool get hasDirectory => projectIO != null;

  /// 动态切换地图目录，清空当前编辑状态
  void setMapsDirectory(String path) {
    projectIO = MapProjectIO(Directory(path));
    _project = null;
    _projectName = null;
    editableMap = null;
    _isDirty = false;
    _selectedCellPos = null;
    _hoveredChunk = null;
    debugPrint('[Editor] Maps directory changed to: $path');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 绘制
  // ---------------------------------------------------------------------------

  /// 在世界坐标上绘制当前画笔
  void paintCell(int worldX, int worldY) {
    final cell = _selectedCell;
    final map = editableMap;
    if (cell == null || map == null) return;

    map.setCell(worldX, worldY, cell);
    _isDirty = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 工程操作
  // ---------------------------------------------------------------------------

  Future<List<String>> listProjects() =>
      projectIO?.listProjects() ?? Future.value([]);

  Future<void> createProject(String name, {int? defaultCellId}) async {
    final io = projectIO;
    if (io == null) return;

    final id = defaultCellId ?? EditorState.defaultCellId;
    final proj = await io.createProject(name, defaultCellId: id);
    _project = proj;
    _projectName = name;
    final map = EditableMap(chunkLoader);
    editableMap = map;
    _isDirty = false;
    _selectedCell ??= cellRegistry.get(id);

    // 自动创建初始区块 (0, 0)
    map.createChunk(0, 0, cellRegistry.get(id));
    proj.chunks.add((x: 0, y: 0));

    final savePath = io.projectDir(name).path;
    debugPrint('[Editor] Created project "$name" at: $savePath');
    notifyListeners();
  }

  Future<void> loadProject(String name) async {
    final io = projectIO;
    if (io == null) return;

    final proj = await io.loadManifest(name);
    final map = EditableMap(chunkLoader);

    for (final coord in proj.chunks) {
      final json = await io.loadChunk(name, coord.x, coord.y);
      map.loadChunk(json);
    }

    _project = proj;
    _projectName = name;
    editableMap = map;
    _isDirty = false;
    _selectedCell ??= defaultCell;

    final savePath = io.projectDir(name).path;
    debugPrint('[Editor] Loaded project "$name" from: $savePath (${proj.chunks.length} chunks)');
    notifyListeners();
  }

  Future<void> deleteProject(String name) async {
    final io = projectIO;
    if (io == null) return;

    await io.deleteProject(name);

    // 如果删除的是当前打开的工程，清空状态
    if (_projectName == name) {
      _project = null;
      _projectName = null;
      editableMap = null;
      _isDirty = false;
      _selectedCellPos = null;
      _hoveredChunk = null;
    }
    debugPrint('[Editor] Deleted project "$name"');
    notifyListeners();
  }

  Future<void> saveProject() async {
    final io = projectIO;
    final proj = _project;
    final name = _projectName;
    final map = editableMap;
    if (io == null || proj == null || name == null || map == null) return;

    proj.modifiedAt = DateTime.now();

    // 同步区块列表
    proj.chunks.clear();
    for (final (cx, cy) in map.loadedChunkKeys) {
      proj.chunks.add((x: cx, y: cy));
    }

    // 保存每个区块
    for (final (cx, cy) in map.loadedChunkKeys) {
      await io.saveChunk(name, map.saveChunk(cx, cy));
    }

    await io.saveManifest(name, proj);
    _isDirty = false;

    final savePath = io.projectDir(name).path;
    debugPrint('[Editor] Saved project "$name" to: $savePath');

    notifyListeners();
  }

  void addChunk(int cx, int cy) {
    final map = editableMap;
    if (map == null || map.isChunkLoaded(cx, cy)) return;

    map.createChunk(cx, cy, defaultCell);
    _isDirty = true;
    _project?.chunks.add((x: cx, y: cy));
    debugPrint('[Editor] Added chunk ($cx, $cy)');
    notifyListeners();
  }

  void removeChunk(int cx, int cy) {
    final map = editableMap;
    if (map == null || !map.isChunkLoaded(cx, cy)) return;

    map.removeChunk(cx, cy);
    _isDirty = true;
    _project?.chunks.removeWhere((c) => c.x == cx && c.y == cy);

    final name = _projectName;
    if (name != null) {
      projectIO?.deleteChunkFile(name, cx, cy);
    }
    debugPrint('[Editor] Removed chunk ($cx, $cy)');
    notifyListeners();
  }
}
