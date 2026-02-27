# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Alebel is a turn-based tactical strategy game built with Flutter and the Flame game engine. It features isometric projection rendering, A* pathfinding, fog of war, and a skill-based combat system.

## Development Commands

```bash
# Flutter version is pinned to 3.38.7 via FVM (.fvmrc)
flutter pub get          # Install dependencies
flutter analyze          # Lint (uses flutter_lints)
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run a single test file
flutter run              # Run the app
```

## Architecture

The codebase follows a three-layer separation: core logic, data models, and presentation.

- `lib/core/` — Game logic and state management
  - `battle/` — Turn system (`TurnManager`: player/enemy turn flow)
  - `map/` — Grid management (`GameMap`), pathfinding (`Board` with A*), cell runtime state (`CellState`)
  - `skills/` — Skill base class with `MoveSkill` and `AttackSkill` implementations
  - `unit/` — Runtime unit state (`UnitState`: position, HP, cooldowns)
  - `buffs/` — Buff/status effect system
- `lib/models/` — Static data definitions
  - `cells/` — Cell types (Ground, Forest, Water, Wall) registered in `cell_registry.dart`
  - `units/` — Unit definitions extending abstract `Unit` class (e.g. `BasicSoldier`)
- `lib/presentation/` — Flame components and rendering
  - `components/` — Entity components (`UnitComponent`, `CellComponent`, `IsometricComponent`)
  - `layers/` — Rendering layers: Background, Grid, Fog, Range, Units, UI
  - `ui/` — HUD overlays (`SelectionOverlay`, `UiLayer`)
- `lib/game/` — Main game loop (`AlebelGame` extends `FlameGame`)

## Key Patterns

- Entry point: `lib/main.dart` → `GameWidget(game: AlebelGame())`
- `AlebelGame` initializes the isometric board with stacked rendering layers and sets up input handling (pan, zoom, click, hover, long-press)
- Units are defined as static models in `models/units/`, with runtime state tracked separately in `core/unit/UnitState`
- Cells follow the same pattern: static config in `models/cells/Cell`, runtime state in `core/map/CellState`
- New units: extend `Unit` in `lib/models/units/`, override `moveRange`, `skills`, etc.
- New cell types: extend `Cell` in `lib/models/cells/`, register in `cell_registry.dart`
- Pathfinding uses A* with a priority queue from the `collection` package

## Key Dependencies

- `flame` ^1.18.0 — Game engine
- `provider` ^6.1.0 — State management
- `collection` ^1.18.0 — Priority queue for A* pathfinding
