import 'package:file_picker/file_picker.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../framework/map/map_chunk.dart';
import 'editor_map_game.dart';
import 'editor_state.dart';

/// 编辑器页面
///
/// 纯 Flutter 布局：左侧 Flame 地图渲染、右侧控制面板。
/// 通过 [Listener] 拦截鼠标事件实现：
/// - 鼠标移动 → 区块悬停高亮（已加载/ghost 都会高亮）
/// - 左键点击已加载区块 → 选中格子 + 绘制
/// - 左键拖拽 → 连续填涂模式（跟随鼠标绘制地形）
/// - 左键点击 ghost 区块 → 创建新区块
/// - 右键拖拽 → 镜头平移
/// - 滚轮 → 镜头缩放
class EditorPage extends StatefulWidget {
  final EditorState editorState;

  const EditorPage({super.key, required this.editorState});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final EditorMapGame _game;
  final _projectNameController = TextEditingController();
  final _chunkXController = TextEditingController(text: '0');
  final _chunkYController = TextEditingController(text: '0');
  List<String> _projectList = [];

  /// 左键是否处于绘制拖拽中
  bool _isPainting = false;

  EditorState get state => widget.editorState;

  @override
  void initState() {
    super.initState();
    _game = EditorMapGame(editorState: state);
    _refreshProjectList();
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _chunkXController.dispose();
    _chunkYController.dispose();
    super.dispose();
  }

  Future<void> _refreshProjectList() async {
    final list = await state.listProjects();
    if (mounted) setState(() => _projectList = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 左侧：Flame 地图 + 鼠标交互
          Expanded(child: _buildMapArea()),
          // 右侧：控制面板
          ListenableBuilder(listenable: state, builder: (context, _) => _buildPanel()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 地图区域（Listener 包裹 GameWidget）
  // ---------------------------------------------------------------------------

  Widget _buildMapArea() {
    return Listener(
      onPointerHover: _onPointerHover,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerSignal: _onPointerSignal,
      child: GameWidget(game: _game),
    );
  }

  /// 鼠标移动（无按钮）→ 更新悬停区块
  void _onPointerHover(PointerHoverEvent event) {
    _updateHoveredChunk(event.localPosition);
  }

  /// 鼠标按下
  /// - 左键：立即在当前位置绘制/创建区块，并进入填涂模式
  /// - 右键：准备平移镜头
  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryButton != 0) {
      // 左键按下：立即绘制当前位置，并标记为填涂模式
      _handlePaint(event.localPosition);
      _isPainting = true;
    }
  }

  /// 鼠标移动（按下状态）
  /// - 左键拖拽：连续填涂
  /// - 右键拖拽：平移镜头
  void _onPointerMove(PointerMoveEvent event) {
    if (event.buttons == 0) {
      _updateHoveredChunk(event.localPosition);
      return;
    }

    if (event.buttons & kSecondaryButton != 0) {
      // 右键拖拽 → 平移镜头
      _game.panCamera(event.delta.dx, event.delta.dy);
    } else if (event.buttons & kPrimaryButton != 0 && _isPainting) {
      // 左键拖拽 → 连续填涂
      _handlePaint(event.localPosition);
    }

    _updateHoveredChunk(event.localPosition);
  }

  /// 鼠标松开 → 结束填涂/平移
  void _onPointerUp(PointerUpEvent event) {
    _isPainting = false;
  }

  /// 处理绘制（选中/绘制格子 或 创建新区块）
  void _handlePaint(Offset localPosition) {
    final worldPos = _game.screenToWorld(localPosition.dx, localPosition.dy);

    final cs = state.cellSize;
    final wx = _pixelToGrid(worldPos.x, cs);
    final wy = _pixelToGrid(worldPos.y, cs);
    final cx = _worldToChunk(wx);
    final cy = _worldToChunk(wy);

    final map = state.editableMap;
    if (map == null) return;

    if (map.isChunkLoaded(cx, cy)) {
      state.selectedCellPos = (wx, wy);
      state.paintCell(wx, wy);
    } else if (state.expandableChunkPositions.contains((cx, cy))) {
      state.addChunk(cx, cy);
    }
  }

  /// 滚轮 → 缩放
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final dy = event.scrollDelta.dy;
      if (dy == 0) return;
      final factor = dy < 0 ? 1.1 : 1 / 1.1;
      _game.zoomCamera(factor);
    }
  }

  /// 根据屏幕位置更新悬停区块（包含未加载位置）
  void _updateHoveredChunk(Offset screenPos) {
    final worldPos = _game.screenToWorld(screenPos.dx, screenPos.dy);
    final cs = state.cellSize;

    final wx = _pixelToGrid(worldPos.x, cs);
    final wy = _pixelToGrid(worldPos.y, cs);
    final cx = _worldToChunk(wx);
    final cy = _worldToChunk(wy);

    state.hoveredChunk = (cx, cy);
  }

  /// 世界像素 → 世界格坐标
  int _pixelToGrid(double pixel, double cellSize) {
    return (pixel / cellSize).floor();
  }

  /// 世界格坐标 → 区块坐标（floor 除法）
  int _worldToChunk(int world) {
    return world >= 0 ? world ~/ MapChunk.size : (world - MapChunk.size + 1) ~/ MapChunk.size;
  }

  // ---------------------------------------------------------------------------
  // 右侧面板
  // ---------------------------------------------------------------------------

  Widget _buildPanel() {
    return SizedBox(
      width: 260,
      child: ColoredBox(
        color: const Color(0xFF1E1E2E),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildDirectorySelector(),
            const SizedBox(height: 16),
            _buildInfoPanel(),
            const SizedBox(height: 16),
            _buildProjectControls(),
            const SizedBox(height: 16),
            _buildPalette(),
            const SizedBox(height: 16),
            _buildChunkManager(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 地图目录选择
  // ---------------------------------------------------------------------------

  Widget _buildDirectorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Directory'),
        Text(
          state.mapsDirectoryPath ?? '(未选择)',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        const SizedBox(height: 4),
        _button('Choose Folder', () async {
          final result = await FilePicker.platform.getDirectoryPath();
          if (result == null) return;
          state.setMapsDirectory(result);
          await _refreshProjectList();
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 信息面板
  // ---------------------------------------------------------------------------

  Widget _buildInfoPanel() {
    final selectedPos = state.selectedCellPos;
    final selectedType = state.selectedCellType;
    final hoveredChunk = state.hoveredChunk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Info'),
        _infoRow('Project', state.projectName ?? '(none)'),
        _infoRow('Chunks', '${state.loadedChunkKeys.length}'),
        _infoRow('Brush', state.selectedCell != null ? state.selectedCell!.name : '(none)'),
        _infoRow('Dirty', state.isDirty ? 'Yes' : 'No'),
        if (hoveredChunk != null)
          _infoRow(
            'Hover',
            'Chunk (${hoveredChunk.$1}, ${hoveredChunk.$2})'
                '${state.isHoveredChunkLoaded ? '' : ' [empty]'}',
          ),
        if (selectedPos != null) ...[
          const Divider(color: Colors.white12, height: 12),
          _infoRow('Selected', '(${selectedPos.$1}, ${selectedPos.$2})'),
          if (selectedType != null) _infoRow('Cell', selectedType.name),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 工程控制
  // ---------------------------------------------------------------------------

  Widget _buildProjectControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Project'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _projectNameController,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Project name',
                  hintStyle: TextStyle(color: Colors.white38),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _button('New', () async {
              final name = _projectNameController.text.trim();
              if (name.isEmpty) return;
              await state.createProject(name);
              _projectNameController.clear();
              await _refreshProjectList();
            }),
          ],
        ),
        const SizedBox(height: 6),
        _button('Save', () => state.saveProject()),
        const SizedBox(height: 6),
        if (_projectList.isNotEmpty) ...[
          const Text('Load:', style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          ..._projectList.map(
            (name) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: InkWell(
                onTap: () async {
                  await state.loadProject(name);
                  await _refreshProjectList();
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: name == state.projectName ? const Color(0x442A7AB5) : Colors.transparent,
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await state.deleteProject(name);
                            await _refreshProjectList();
                          },
                          child: const Icon(Icons.close, color: Colors.red, size: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 地形选择器
  // ---------------------------------------------------------------------------

  Widget _buildPalette() {
    final entries = state.cellRegistry.entries;
    final colors = state.cellColors;
    final selectedId = state.selectedCell?.id;

    // 确保 selectedId 在选项中，否则设为 null
    final validSelectedId = selectedId != null && entries.containsKey(selectedId)
        ? selectedId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Terrain'),
        DropdownButton<int>(
          value: validSelectedId,
          isExpanded: true,
          dropdownColor: const Color(0xFF2D2D3E),
          hint: const Text('Select terrain', style: TextStyle(color: Colors.white38, fontSize: 12)),
          underline: const SizedBox.shrink(),
          items: entries.entries.map((entry) {
            final id = entry.key;
            final cell = entry.value;
            final color = colors[id] ?? const Color(0xFF888888);
            return DropdownMenuItem<int>(
              value: id,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(cell.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id != null) {
              state.selectedCell = entries[id];
            }
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 区块管理
  // ---------------------------------------------------------------------------

  Widget _buildChunkManager() {
    final chunks = state.loadedChunkKeys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Chunks'),
        Row(
          children: [
            _smallField(_chunkXController, 'X'),
            const SizedBox(width: 4),
            _smallField(_chunkYController, 'Y'),
            const SizedBox(width: 6),
            _button('Add', () {
              final cx = int.tryParse(_chunkXController.text) ?? 0;
              final cy = int.tryParse(_chunkYController.text) ?? 0;
              state.addChunk(cx, cy);
            }),
          ],
        ),
        const SizedBox(height: 6),
        ...chunks.map((key) {
          final (cx, cy) = key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chunk ($cx, $cy)',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
                GestureDetector(
                  onTap: () => state.removeChunk(cx, cy),
                  child: const Icon(Icons.close, color: Colors.red, size: 16),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 辅助
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF2A7AB5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _smallField(TextEditingController controller, String hint) {
    return SizedBox(
      width: 50,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        ),
      ),
    );
  }
}
