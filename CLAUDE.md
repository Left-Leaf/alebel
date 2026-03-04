# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Alebel is a turn-based tactical strategy game built with Flutter and the Flame game engine. It features isometric projection rendering, A* pathfinding, fog of war, and a skill-based combat system. The game has two modes: exploration (top-down WASD movement) and battle (isometric turn-based tactical combat with ATB gauge system).

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

The codebase follows a four-layer separation: core logic, data models, presentation, and game orchestration.

- `lib/core/` — Game logic and state management (no Flame dependency)
  - `battle/` — ATB (Active Time Battle) turn system. `TurnManager` fills action gauges based on unit speed; gauge hits 1000 → unit acts. `BattleAPI` is the abstract interface that skills use to execute effects and control interaction state. `BattleScenario` defines unit spawn configuration for a battle. `TurnDelegate` is the interface for turn lifecycle notifications (implemented by `BattleController`). `BattlePresenter` is the interface for visual effects (implemented in game layer).
  - `ai/` — `AIStrategy` abstract interface for per-unit AI behavior. `AggressiveAI` is the default implementation (greedy approach + attack). AI decision methods are pure — no side effects during planning.
  - `map/` — `GameMap` stores 2D grid of `CellState`. `Board` extension provides BFS pathfinding (`getMovablePositions`) and ray-cast vision (`getVisiblePositions`). `Position` typedef: `({int x, int y})`.
  - `skills/` — Abstract `Skill` base class with `MoveSkill` and `AttackSkill` as `part` files. `onTap` receives `BattleAPI`, executes effects directly, returns `Future<bool>` (true = action executed, false = interaction-only change). MoveSkill uses two-tap flow: first tap → preview, second tap → confirm.
  - `unit/` — `UnitState` composed of 6 mixins (`HealthMixin`, `AttackMixin`, `ActionPointMixin`, `VisionMixin`, `ActionGaugeMixin`, `SkillRecordMixin`). Tracks runtime state: position, HP, AP, buffs, `turnSkillHistory`.
  - `buffs/` — Abstract `Buff` base class with priority-based application and per-turn hooks (all async). Implementations (`PoisonBuff`, `AttackBoostBuff`, `SpeedDebuffBuff`) as `part` files.
  - `game_mode.dart` — `GameMode` enum: `{exploration, battle}`.
- `lib/models/` — Static data definitions (immutable configs)
  - `cells/` — Cell types (Ground, Forest, Water, Wall) as `part` files of `cell_base.dart`, registered in `cell_registry.dart` by integer ID. `Cell` has mixins `RenderCell` (custom canvas drawing) and `SpriteCell` (sprite asset path).
  - `units/` — Unit definitions extending abstract `Unit` class (e.g. `BasicSoldier`). Defines stats, skills, faction, `aiStrategy`.
- `lib/presentation/` — Flame components and rendering
  - `components/` — `IsometricComponent` applies 30° isometric matrix transform to all children. `AnimatableIsoDecorator` interpolates between top-down (factor=0) and full isometric (factor=1) for smooth transitions. `CellComponent` (50x50 px) and `UnitComponent` handle entity rendering and input. `ExplorerComponent` is the lightweight exploration-mode player avatar. `FloatingTextComponent` is a self-removing animated text effect (float up + fade out).
  - `layers/` — Stacked rendering layers by priority: Grid(1) → OriginPoint(2) → Fog(3) → SelectionOverlay(4) → Range(5) → Units(6) → Effects(7). All inside `BoardComponent` with `AnimatableIsoDecorator`.
  - `ui/` — `UiLayer` is attached to camera viewport (screen-fixed). Contains info text, turn order display, skill buttons, end turn button, debug mode toggle, and `BattleEndOverlay` (VICTORY/DEFEAT text).
- `lib/game/` — Game orchestration and Flame integration
  - `AlebelGame` — Entry point `FlameGame` subclass. Manages camera, zoom, mode transitions (exploration ↔ battle with two-phase animation), and input routing.
  - `BoardComponent` — Central container holding all layers, `GameMap`, `TurnManager`. Manages battle lifecycle (`initBattle`/`teardownBattle`), fog updates, coordinate transforms through interpolated isometric projection. Creates `_BoardBattlePresenter` (implements `BattlePresenter`) to bridge `BattleController` to presentation layer.
  - `BattleController` — Implements `BattleAPI` and `TurnDelegate`. Handles focus system, skill execution, AI turns, unit death, battle end detection. Drives visual effects through `BattlePresenter` interface. All effect methods (`damageUnit`, `healUnit`, `addBuff`, `removeBuff`) are async. Loaded/unloaded with battle mode.
  - `ExplorationController` — Keyboard input handler for WASD/arrow exploration movement with held-key repeat.
- `lib/common/` — `assets.dart` (centralized asset paths), `constants.dart` (all numeric constants: grid, ATB, animation, camera, fog), `theme.dart` (color constants).

## Key Patterns

- Entry point: `lib/main.dart` → `GameWidget(game: AlebelGame())`
- **Static vs Runtime separation**: `Unit`/`Cell` are immutable configs; `UnitState`/`CellState` track mutable runtime data. New instances of `UnitState` reference a shared `Unit` definition.
- **BattleAPI pattern**: Skills receive a `BattleAPI` instance and call its methods (`damageUnit`, `moveUnit`, `healUnit`, `addBuff`, `setFocus`, `setPreview`, `switchSkill`, `displaceUnit`) to execute effects. `BattleController` implements this interface. Skills never return intermediate result types — they act directly through the API. All effect methods (`damageUnit`, `healUnit`, `addBuff`, `removeBuff`) are async and drive visual effects through `BattlePresenter`. `damageUnit` accepts optional `attacker` parameter to trigger buff damage hooks.
- **AI strategy pattern**: `Unit.aiStrategy` returns an `AIStrategy` instance (default: `AggressiveAI`). `BattleController` reads the strategy from the unit definition — no hardcoded AI. AI `decideTurn()` is pure (no side effects); execution happens via `BattleAPI`.
- **Battle scenario pattern**: `BattleScenario` describes enemy/ally spawns as `UnitSpawn` list with position offsets. Pass to `game.startTransitionToBattle(scenario: ...)`. `BoardComponent.initBattle` generates units from the config.
- **Part files pattern**: `Buff`, `Skill`, `Cell` all use abstract base class with implementations in `part` files. Extend these the same way.
- **Cell runtime effects**: `Cell` base class provides `moveCost` (default 1), `onUnitEnter(UnitState)` (async, called after each movement step), and `onTurnStart(UnitState)` (async, called at turn start after buff processing). Override in cell subclasses for terrain effects.
- **Buff reactive hooks**: `Buff.onDamageTaken(state, damage)` returns `Future<int>` modified damage (for shields/damage reduction). `Buff.onDamageDealt(state, target, damage)` fires after damage is applied (for lifesteal/chain effects). All buff hooks are async. These hooks are called automatically by `BattleController.damageUnit` when `attacker` is provided.
- **Cost-based pathfinding**: `BoardImpl.getMoveCost(x, y)` returns per-cell movement cost. BFS uses accumulated cost tracking (`bestCost` map) instead of step counting, supporting variable terrain costs.
- **Registry pattern**: `CellRegistry` maps integer IDs to `Cell` instances for map serialization.
- **Focus system**: `BattleController.focusCell` drives selection highlight; `focusUnit` (derived from focusCell) drives skill interaction and range display.
- **Async movement**: `BattleAPI.moveUnit()` uses `Completer` to chain `MoveToEffect` animations step-by-step, updating fog after each step.
- **Event-driven effects**: `BattleController` drives visual effects through `BattlePresenter` interface. `_BoardBattlePresenter` (in `board_component.dart`) implements this interface, spawning `FloatingTextComponent` on the `EffectLayer` and adding `BattleEndOverlay` to `UiLayer`. All presenter methods are async (currently fire-and-forget, can await animations in the future).
- **TurnDelegate pattern**: `TurnManager` notifies `BattleController` of turn lifecycle events via the `TurnDelegate` interface. All delegate methods are async, enabling the full call chain (`damageUnit → death → battleEnd → cleanup`) to be properly awaited without reentry issues.
- **Two-phase mode transitions**: Exploration ↔ Battle animated over 1.5s. Phase 1: isometric projection interpolation (factor 0↔1). Phase 2: camera pan + zoom. `AnimatableIsoDecorator` drives the projection interpolation. Coordinate transform overrides on `BoardComponent` support hit-testing through any interpolation state.

## Extension Guide

- New skills: extend `Skill` as `part` file in `lib/core/skills/`, implement `onTap(state, target, api)` using `BattleAPI` methods, return `true` if an action was executed. Add to `Unit.skills` list.
- New units: extend `Unit` in `lib/models/units/`, override `moveRange`, `skills`, `aiStrategy`, etc.
- New cell types: extend `Cell` as `part` file in `lib/models/cells/cell_base.dart`, register in `cell_registry.dart`. Override `moveCost`, `onUnitEnter()`, `onTurnStart()` for terrain effects. Use `SpriteCell` mixin for sprite-based or `RenderCell` mixin for canvas-based rendering.
- New buffs: extend `Buff` as `part` file in `lib/core/buffs/buff.dart`, implement `apply()`, optionally override `onTurnStart()` / `onTurnEnd()` / `onDamageTaken()` / `onDamageDealt()` (all async).
- New AI strategies: extend `AIStrategy` in `lib/core/ai/`, implement `decideTurn()`. Assign to `Unit.aiStrategy`.

## UI Conventions

- Prefer `StatelessWidget`; avoid `StatefulWidget` unless necessary.
- Avoid `Container`; use `DecoratedBox`, `Padding`, `Align`, `SizedBox`, `ColorBox` instead.
- All widgets should be adaptive-sized; avoid fixed dimensions unless required.
- Use centralized color definitions from `lib/common/theme.dart` and asset paths from `lib/common/assets.dart`.
- All numeric constants (durations, sizes, thresholds) go in `lib/common/constants.dart`.

## Key Dependencies

- `flame` ^1.18.0 — Game engine
- `collection` ^1.18.0 — Priority queue for pathfinding
