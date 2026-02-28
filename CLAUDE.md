# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Alebel is a turn-based tactical strategy game built with Flutter and the Flame game engine. It features isometric projection rendering, A* pathfinding, fog of war, and a skill-based combat system.

## Development Commands

```bash
# Flutter version is pinned to 3.38.7 via FVM (.fvmrc)
# ALL flutter commands MUST use fvm prefix
fvm flutter pub get          # Install dependencies
fvm flutter analyze          # Lint (uses flutter_lints)
fvm flutter test             # Run all tests
fvm flutter test test/widget_test.dart  # Run a single test file
fvm flutter run              # Run the app
```

## Architecture

The codebase follows a three-layer separation: core logic, data models, and presentation.

- `lib/core/` — Game logic and state management
  - `battle/` — ATB (Active Time Battle) turn system. `TurnManager` fills action gauges based on unit speed; gauge hits 1000 → unit acts.
  - `map/` — `GameMap` stores 2D grid of `CellState`. `Board` extension provides A* pathfinding (`getMovablePositions`) and ray-cast vision (`getVisiblePositions`). `Position` typedef: `({int x, int y})`.
  - `skills/` — Sealed `Skill` base class with `MoveSkill` and `AttackSkill` as `part` files. `onCellTap` returns `bool` (true = skill executed). MoveSkill uses two-tap flow: first tap → preview, second tap → confirm.
  - `unit/` — `UnitState` tracks runtime state (position, HP, action points, buffs, `turnSkillHistory`).
  - `buffs/` — Sealed `Buff` base class with priority-based application and per-turn hooks.
- `lib/models/` — Static data definitions (immutable configs)
  - `cells/` — Cell types (Ground, Forest, Water, Wall) registered in `cell_registry.dart` by integer ID.
  - `units/` — Unit definitions extending abstract `Unit` class (e.g. `BasicSoldier`). Defines stats, skills, faction.
- `lib/presentation/` — Flame components and rendering
  - `components/` — `IsometricComponent` applies 30° isometric matrix transform to all children. `CellComponent` (50x50 px) and `UnitComponent` handle individual entity rendering and input.
  - `layers/` — Stacked rendering layers by priority: Background(-1) → Grid(1) → Fog(3) → SelectionOverlay(4) → Range(5) → Units(6). All inside `IsometricComponent` except Background.
  - `ui/` — `UiLayer` is attached to camera viewport (screen-fixed). Contains info text, turn order display, skill buttons, end turn button.
- `lib/game/` — `AlebelGame extends FlameGame`: entry point, initializes board/layers/units, handles all input delegation.
- `lib/common/` — `assets.dart` (centralized asset paths), `theme.dart` (color constants with brightness-aware selection).

## Key Patterns

- Entry point: `lib/main.dart` → `GameWidget(game: AlebelGame())`
- **Static vs Runtime separation**: `Unit`/`Cell` are immutable configs; `UnitState`/`CellState` track mutable runtime data. New instances of `UnitState` reference a shared `Unit` definition.
- **Sealed class + part files**: `Skill` and `Buff` use sealed base classes with implementations in `part` files. Extend these the same way.
- **Registry pattern**: `CellRegistry` maps integer IDs to `Cell` instances for map serialization.
- **Focus system**: `AlebelGame.focusCell` drives selection highlight; `focusUnit` (derived from focusCell) drives skill interaction and range display.
- **Async movement**: `MoveSkill._confirmMovement()` uses `Completer` to chain `MoveToEffect` animations step-by-step, updating fog after each step.
- New units: extend `Unit` in `lib/models/units/`, override `moveRange`, `skills`, etc.
- New cell types: extend `Cell` in `lib/models/cells/`, register in `cell_registry.dart`.

## UI Conventions

- Prefer `StatelessWidget`; avoid `StatefulWidget` unless necessary.
- Avoid `Container`; use `DecoratedBox`, `Padding`, `Align`, `SizedBox`, `ColorBox` instead.
- All widgets should be adaptive-sized; avoid fixed dimensions unless required.
- Use centralized color definitions from `lib/common/theme.dart` and asset paths from `lib/common/assets.dart`.

## Key Dependencies

- `flame` ^1.18.0 — Game engine
- `provider` ^6.1.0 — State management
- `collection` ^1.18.0 — Priority queue for A* pathfinding
