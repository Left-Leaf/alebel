# Extension Guide

This guide explains how to add new content to the game.

## Adding a New Unit

1. Create a new file in `lib/models/units/`.
2. Create a class extending `Unit` (or `UnitBase` if you renamed it).
3. Override required properties (`moveRange`, `skills`, etc.).

Example:
```dart
// lib/models/units/archer.dart
import 'unit_base.dart';

class Archer extends Unit {
  @override
  int get moveRange => 3;
  @override
  int get attackRange => 3;
  // ...
  
  Archer({required super.color, super.faction});
}
```

## Adding a New Cell Type

1. Create a new file in `lib/models/cells/`.
2. Create a class extending `Cell`.
3. Implement the `render` method for custom drawing.
4. Register the new cell in `lib/models/cells/cell_registry.dart`.

Example:
```dart
// lib/models/cells/lava_cell.dart
class LavaCell extends Cell {
  const LavaCell() : super(name: 'Lava', blocksMovement: true);

  @override
  void render(Canvas canvas, Size size) {
    // Draw lava
  }
}
```

In `cell_registry.dart`:
```dart
static final Map<int, Cell> _cells = {
  // ...
  4: const LavaCell(),
};
```
