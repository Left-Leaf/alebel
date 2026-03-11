import 'package:flutter/material.dart';

import 'cell/cells.dart';
import 'editor/editor_page.dart';
import 'editor/editor_state.dart';
import 'framework/map/chunk_loader.dart';
import 'framework/map/entity_factory.dart';
import 'framework/map/state_factory.dart';

void main() {
  final cellRegistry = buildPresetCellRegistry();
  final chunkLoader = ChunkLoader(
    cellRegistry: cellRegistry,
    entityFactory: EntityFactory(EntityRegistry()),
    stateFactory: StateFactory(StateRegistry()),
  );

  final editorState = EditorState(
    cellRegistry: cellRegistry,
    cellColors: presetCellColors,
    cellImagePaths: presetCellImagePaths,
    chunkLoader: chunkLoader,
  );

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EditorPage(editorState: editorState),
    ),
  );
}
