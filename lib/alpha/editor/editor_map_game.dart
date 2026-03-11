import 'package:flame/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'editor_chunk_renderer.dart';
import 'editor_state.dart';

/// 编辑器地图渲染游戏
///
/// 极简 FlameGame，职责仅限于渲染区块网格。
/// 已加载的区块用 [EditorChunkRenderer] 渲染（支持材质图），
/// 相邻的空位用 [GhostChunkRenderer] 渲染扩展提示。
/// 所有输入交互由外层 Flutter [Listener] 处理。
class EditorMapGame extends FlameGame {
  final EditorState editorState;

  EditorMapGame({required this.editorState});

  final Map<(int, int), EditorChunkRenderer> _renderers = {};
  final Map<(int, int), GhostChunkRenderer> _ghosts = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera = CameraComponent(world: world);
    camera.viewfinder.zoom = 3;

    // 加载所有材质图
    for (final entry in editorState.cellImagePaths.entries) {
      try {
        final image = await images.load(entry.value);
        editorState.cellImages[entry.key] = image;
      } catch (e) {
        debugPrint('[Editor] Failed to load image for cell ${entry.key}: $e');
      }
    }

    editorState.addListener(_onStateChanged);
    _syncRenderers();
  }

  @override
  void onRemove() {
    editorState.removeListener(_onStateChanged);
    super.onRemove();
  }

  void _onStateChanged() {
    _syncRenderers();
  }

  // ---------------------------------------------------------------------------
  // 区块 renderer 同步
  // ---------------------------------------------------------------------------

  void _syncRenderers() {
    final loadedKeys = editorState.loadedChunkKeys.toSet();

    // --- 已加载区块 renderer ---

    // 移除不再存在的
    final toRemove =
        _renderers.keys.where((k) => !loadedKeys.contains(k)).toList();
    for (final key in toRemove) {
      _renderers.remove(key)?.removeFromParent();
    }

    // 添加新出现的
    for (final key in loadedKeys) {
      if (!_renderers.containsKey(key)) {
        final (cx, cy) = key;
        final renderer = EditorChunkRenderer(
          chunkX: cx,
          chunkY: cy,
          editorState: editorState,
        );
        _renderers[key] = renderer;
        world.add(renderer);
      }
    }

    // --- 空区块 ghost renderer ---

    final expandable = editorState.expandableChunkPositions;

    // 移除不再需要的 ghost
    final ghostToRemove =
        _ghosts.keys.where((k) => !expandable.contains(k)).toList();
    for (final key in ghostToRemove) {
      _ghosts.remove(key)?.removeFromParent();
    }

    // 添加新的 ghost
    for (final key in expandable) {
      if (!_ghosts.containsKey(key)) {
        final (cx, cy) = key;
        final ghost = GhostChunkRenderer(
          chunkX: cx,
          chunkY: cy,
          editorState: editorState,
        );
        _ghosts[key] = ghost;
        world.add(ghost);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 镜头控制（由外层 Flutter Listener 调用）
  // ---------------------------------------------------------------------------

  /// 平移镜头（屏幕像素增量）
  void panCamera(double dx, double dy) {
    final zoom = camera.viewfinder.zoom;
    camera.viewfinder.position -= Vector2(dx / zoom, dy / zoom);
  }

  /// 缩放镜头
  void zoomCamera(double factor) {
    camera.viewfinder.zoom =
        (camera.viewfinder.zoom * factor).clamp(0.3, 20.0);
  }

  /// 屏幕坐标 → 世界坐标
  Vector2 screenToWorld(double screenX, double screenY) {
    final viewportSize = camera.viewport.size;
    final viewfinderPos = camera.viewfinder.position;
    final zoom = camera.viewfinder.zoom;

    final worldX = viewfinderPos.x + (screenX - viewportSize.x / 2) / zoom;
    final worldY = viewfinderPos.y + (screenY - viewportSize.y / 2) / zoom;
    return Vector2(worldX, worldY);
  }
}
