# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Alebel is a turn-based tactical strategy game built with Flutter and the Flame game engine. It features interpolated isometric projection rendering, cost-based BFS pathfinding, ray-cast fog of war (center/edge dual visibility), and a skill-based combat system. The game has two modes: exploration (top-down WASD movement) and battle (isometric turn-based tactical combat with ATB gauge system).

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
  - `battle/` — ATB (Active Time Battle) turn system.
    - `TurnManager` — Fills action gauges based on unit speed; gauge hits 1000 -> unit acts. Uses iterative `_advanceTurn()` loop (not recursive) to handle ATB progression, buff/cell deaths, and turn sequencing. Separates gauge filling (`_fillActionQueue`) from turn lifecycle. Maintains `_positionIndex` spatial index for O(1) `getUnitAt` lookups; callers must use `updateUnitPosition()` to move units.
    - `BattleAPI` — Abstract interface that skills/AI use to execute effects and control interaction state. Methods: query (`activeUnit`, `getUnitAt`, `gameMap`), interaction control (`setFocus`, `setPreview`, `clearPreview`, `switchSkill`), game effects (`moveUnit`, `damageUnit`, `healUnit`, `addBuff`, `removeBuff`, `displaceUnit`), unified skill execution (`executeSkill` — checks canUse, calls onTap, spends AP, records usage).
    - `BattleEffects` — Mixin implementing 5 shared `BattleAPI` methods (`damageUnit`, `healUnit`, `addBuff`, `removeBuff`, `executeSkill`). Requires `presenter` getter and `onUnitKilled` callback. Used by `BattleController` and test mocks to eliminate code duplication.
    - `BattlePresenter` — Abstract interface for visual effects, defined in core, implemented in game layer. Methods: `showDamage`, `showHeal`, `showDeath`, `showBuffApplied`, `showBuffRemoved`, `showBattleEnd`. All async.
    - `TurnDelegate` — Abstract interface for turn lifecycle notifications (implemented by `BattleController`). Methods: `onTurnStart`, `onTurnEnd`, `onBuffTurnStart`, `onBuffTurnEnd`, `onCellTurnStart`, `onUnitDeath`. All async.
    - `BattleScenario` — Defines unit spawn configuration (enemies + optional allies as `UnitSpawn` list with position offsets).
  - `ai/` — AI strategy system.
    - `AIStrategy` — Abstract interface, single pure method `decideTurn(UnitState, AIContext) -> List<AIAction>`.
    - `AggressiveAI` — Default implementation: find nearest enemy (manhattan distance), approach via pathfinding, attack if in range.
    - `AIAction` — Abstract base with `execute(UnitState, BattleAPI)`. Subtypes: `AIMove(path)`, `AIUseSkill(skill, target)` (executes through `BattleAPI.executeSkill` to share AP/cooldown/recording logic with player).
    - `AIContext` — Read-only decision context: `gameMap`, `units`, `getUnitAt`.
  - `map/` — Grid and spatial algorithms.
    - `Position` typedef: `({int x, int y})`.
    - `BoardImpl` — Abstract interface for grid queries: `blocksPass`, `blocksVision`, `canStand`, `isCellKnown`, `getMoveCost`.
    - `BoardExtension` — BFS pathfinding (`getMovablePositions` with cost-based SPFA and path certainty tracking) and ray-cast vision (`getVisiblePositions` with center/edge dual visibility model).
    - `GameMap` — Implements `BoardImpl`. Stores column-major 2D grid of `CellState`. Provides fog of war management (`updateFog`), factory constructors (`fromMatrix`, `standard`).
    - `CellState` — Runtime cell data: `cell` reference, position, `fogState`, `isCenterVisible`, dynamic blocking properties.
    - `FogState` enum: `visible` (opacity 0), `explored` (opacity 0.5), `unknown` (opacity 1.0).
    - `PathCertainty` enum: `confirmed` (all cells known), `uncertain` (path through unknown territory).
  - `skills/` — Abstract `Skill` base class with `MoveSkill` and `AttackSkill` as `part` files.
    - `Skill` — Properties: `name`, `cost`, `cooldown`, `maxUsesPerTurn`. Methods: `onTap(state, target, api) -> Future<bool>`, `getHighlightPositions(state, ctx)`. Static utility: `getPositionsInRange()`.
    - `MoveSkill` — Two-tap flow: first tap -> preview (setPreview + ghost unit), second tap -> confirm (moveUnit). `maxUsesPerTurn = 1`.
    - `AttackSkill` — Validates range/visibility/faction, calls `damageUnit` with attacker. `maxUsesPerTurn = 1`.
    - `SkillContext` — Read-only context for highlight computation: `gameMap`, `activeUnit`, `getUnitAt`.
  - `unit/` — `UnitState` composed of 6 mixins:
    - `HealthMixin` — `maxHp`, `currentHp`, `isDead`, `isAlive`, `takeDamage()`, `heal()`, `clampHp()`.
    - `AttackMixin` — `currentAttack` getter/setter.
    - `ActionPointMixin` — `maxActionPoints`, `currentActionPoints`, `recoveryActionPoints`, `spendAp()`, `recoverAp()`, `hasAp`.
    - `VisionMixin` — `currentVisionRange`.
    - `ActionGaugeMixin` — `currentSpeed`, `actionGauge`.
    - `SkillRecordMixin` — `focusSkill`, `turnSkillHistory`, `usesThisTurn()`, `remainingCooldown()`, `lastUsedTurnIndex()`, `beginTurnRecord()`, `recordSkill()`.
    - `UnitState` — Composes all mixins. Tracks: position (`x`, `y`), `previewPosition`, `buffs` list. Methods: `addBuff()`, `removeBuff()` (trigger `recalculateAttributes`), `canUse(Skill)`.
  - `buffs/` — Abstract `Buff` base class with priority-based application and per-turn hooks (all async). Implementations as `part` files via export:
    - `Buff` — Properties: `id`, `name`, `description`, `duration`, `priority` (0 = evaluated first). Methods: `apply(state)`, `onTurnStart()`, `onTurnEnd() -> bool` (true = expired), `onDamageTaken() -> int` (modified damage), `onDamageDealt()`.
    - `PoisonBuff` — Deals damage via `api.damageUnit` at turn start.
    - `AttackBoostBuff` — Increases `currentAttack` (priority=10).
    - `SpeedDebuffBuff` — Reduces `currentSpeed`, clamps to 0 (priority=10).
  - `game_mode.dart` — `GameMode` enum: `{exploration, battle}`.
- `lib/models/` — Static data definitions (immutable configs)
  - `cells/` — Cell types as `part` files of `cell_base.dart`, registered in `cell_registry.dart` by integer ID.
    - `Cell` — Abstract base. Properties: `name`, `blocksVision`, `blocksMovement`, `canStand`, `moveCost`. Hooks: `onUnitEnter(unit, {api})`, `onTurnStart(unit, {api})`.
    - Mixins: `RenderCell` (custom `render(Canvas, Size)`), `SpriteCell` (`imagePath` getter).
    - Types: `GroundCell` (ID:0, walkable), `WallCell` (ID:1, blocks all), `WaterCell` (ID:2, blocks movement), `ForestCell` (ID:3, blocks vision only, uses RenderCell).
    - `CellRegistry` — Maps integer IDs to `Cell` instances for serialization.
  - `units/` — Unit definitions extending abstract `Unit` class.
    - `Unit` — Abstract. Properties: `color`, `faction`. Abstract: `moveRange`, `visionRange`, `attackRange`, `attack`, `speed`, `maxHp`, `moveSkill`, `skills`. Optional: `aiStrategy` (defaults to `AggressiveAI`).
    - `UnitFaction` enum: `player`, `enemy`, `ally`, `neutral`. Has `isHostileTo(other)` method for faction hostility checks (player/ally hostile to enemy, and vice versa; neutral hostile to none).
    - `BasicSoldier` — Concrete implementation with configurable stats (defaults: moveRange=5, visionRange=5, attackRange=1, attack=10, speed=10, maxHp=100).
- `lib/presentation/` — Flame components and rendering
  - `components/`
    - `IsometricComponent` — Static-only geometric utilities. 30-degree isometric matrix, `project(x,y)`, `projectedBoundingBoxSize()`, coordinate transform overrides for hit-testing through projection.
    - `AnimatableIsoDecorator` — Flame `Decorator` that linearly interpolates between identity (factor=0) and full isometric (factor=1). Exposes `matrixComponents` getter for manual matrix math.
    - `CellComponent` — 50x50 px grid cell. References `CellState`. Renders sprite/canvas based on cell mixin type, border lines, yellow selection border. Routes tap/long-press to `BoardComponent`.
    - `UnitComponent` — Circle rendering with shadow. References `UnitState`. Visibility logic: always render preview units (opacity < 0.99), always render player faction, otherwise only if `cell.isCenterVisible`.
    - `ExplorerComponent` — Lightweight exploration-mode avatar. References `Unit` definition only (no `UnitState`). Simple circle rendering.
    - `FloatingTextComponent` — Self-removing animated text: float upward + fade out. Placed in board-local coordinates (EffectLayer), moves with the board to avoid camera-drift. Auto-removes after `floatDuration`.
    - `OriginPoint` — Yellow crosshair at (0,0) for debugging.
  - `layers/` — Stacked rendering layers by priority inside `BoardComponent`:
    - `GridLayer` (1) — All `CellComponent` instances. Methods: `getCell(x, y)`, `addCell()`.
    - `OriginPoint` (2) — Debug marker.
    - `FogLayer` (3) — `FogCellComponent` per grid cell with opacity transitions based on `FogState`.
    - `SelectionOverlay` (4) — Renders cell selection highlights.
    - `RangeLayer` (5) — Renders skill range highlights. Methods: `updateRanges(coloredPositions)`, `clear()`.
    - `UnitLayer` (6) — All `UnitComponent` instances. Methods: `addUnit()`, `removeUnit()`, `getUnitAt(x, y)`, `units` getter.
    - `EffectLayer` (7) — Floating text and visual effects.
  - `ui/` — `UiLayer` attached to camera viewport (screen-fixed):
    - Info text (current unit, position, HP, AP, skill).
    - `TurnOrderDisplay` — Active unit + predicted next 3.
    - `SkillButtons` — Dynamic, one per skill.
    - `EndTurnButton`.
    - `DebugModeButton` — Toggle exploration/battle.
    - `BattleEndOverlay` — VICTORY/DEFEAT text with fade animation.
- `lib/game/` — Game orchestration and Flame integration
  - `AlebelGame` — Entry point `FlameGame` subclass. Manages camera, zoom, two-phase mode transitions (exploration <-> battle), input routing (pan/scroll in battle mode), camera clamping to projected board bounds. Registers `CellRegistry` on load.
  - `BoardComponent` — Central container. Holds all layers, `GameMap`, `TurnManager`, `FogController`. Manages battle lifecycle (`initBattle`/`teardownBattle`). Provides interpolated isometric coordinate transforms (`projectLocal`, `_undoIso`, `_applyIso`). Creates `BoardBattlePresenter` to bridge battle logic to visual effects. Delegates cell events to `BattleController`.
  - `BattleController` — Mixes in `BattleEffects`, implements `BattleAPI` and `TurnDelegate`. Loaded/unloaded with battle mode.
    - **Focus system**: `focusCell` drives selection; `focusUnit` derived from it.
    - **Skill execution**: `onCellTap()` -> lock -> `skill.onTap()` -> spend AP -> record -> unlock.
    - **AI turns**: Lock -> create `AIContext` -> get actions from `unit.aiStrategy` -> execute each -> `endTurn()` -> unlock.
    - **Damage chain**: (via `BattleEffects`) `damageUnit()` -> target buff `onDamageTaken` hooks -> `takeDamage` -> presenter `showDamage` -> attacker buff `onDamageDealt` hooks -> death check.
    - **Death handling**: Remove from `TurnManager` + `UnitLayer` -> presenter `showDeath` -> update fog -> check battle end.
    - **Battle end**: No enemies = victory, no players = defeat. Calls `cleanup()` then mode transition.
    - **Preview system**: Ghost `UnitComponent` with 0.5 opacity for move preview.
    - **Movement**: Uses `TurnManager.updateUnitPosition()` for spatial index consistency. Units can pass through intermediate occupied cells; only the final destination is checked for occupancy.
  - `ExplorationController` — `KeyboardHandler` component. WASD/arrow input with 0.15s repeat interval. Validates bounds and terrain. Animates with `MoveToEffect`. Updates camera follow and fog.
  - `BoardBattlePresenter` — Implements `BattlePresenter`. Receives dependencies via constructor injection (effectLayer, iso factor/matrix closures, UI layer finder). Spawns `FloatingTextComponent` on `EffectLayer`.
  - `FogController` — Encapsulates fog update logic. Receives `GameMap` and a vision source callback. `updateFog()` delegates to `GameMap.updateFog()`.
- `lib/common/` — Shared definitions.
  - `constants.dart` — `GameConstants` abstract final class. Grid (cellSize=50), ATB (maxGauge=1000), animation speeds (move=200, backtrack=300, fogFade=0.25), fog opacity, camera (explorationZoom=2, battleZoom=1, maxZoom=10, transition=1.5s, dragThreshold=5, zoomMultipliers), exploration (moveInterval=0.15), float text (duration=0.8, distance=30, fadeDelay=0.2), battle end overlay (fadeDuration=0.5, displayDuration=2.0), map defaults (size=40, border=2).
  - `theme.dart` — `AlebelTheme` color constants. Highlights (moveConfirmed, moveUncertain, attackRange). Float text colors (damage, heal, death, buffApplied, buffRemoved, victory, defeat). `ColorTheme` extension with `|` operator for light/dark mode.
  - `assets.dart` — Centralized asset paths.

## Key Patterns

- Entry point: `lib/main.dart` -> `GameWidget(game: AlebelGame())`
- **Static vs Runtime separation**: `Unit`/`Cell` are immutable configs; `UnitState`/`CellState` track mutable runtime data. New `UnitState` instances reference shared `Unit` definitions.
- **BattleAPI pattern**: Skills receive a `BattleAPI` instance and call its methods to execute effects. `BattleController` implements this interface via `BattleEffects` mixin. Skills never return intermediate result types -- they act directly through the API. All effect methods are async and drive visual effects through `BattlePresenter`. `BattleAPI.executeSkill()` is the unified entry point for both player clicks and AI actions, ensuring consistent AP/cooldown/recording logic.
- **BattleEffects mixin**: Shared implementation of `damageUnit`, `healUnit`, `addBuff`, `removeBuff`, `executeSkill`. Requires `presenter` getter and `onUnitKilled` callback. Used by `BattleController` (production) and test mocks to eliminate code duplication.
- **BattlePresenter pattern**: Visual effects driven through abstract `BattlePresenter` interface. Core layer defines it, game layer (`BoardBattlePresenter`) implements it via constructor-injected dependencies. Enables future VFX changes without touching core logic.
- **Spatial index**: `TurnManager._positionIndex` maps `Position` to `UnitState` for O(1) `getUnitAt` lookups. All position mutations must go through `updateUnitPosition()` to keep the index consistent. `registerUnit`/`removeUnit` also maintain the index. Identity check in `removeUnit` (`_positionIndex[pos] == unit`) prevents misdeleting when multiple units share a position.
- **BattlePresenter pattern**: Visual effects driven through abstract `BattlePresenter` interface. Core layer defines it, game layer (`BoardBattlePresenter`) implements it via constructor-injected dependencies. Enables future VFX changes without touching core logic.
- **TurnDelegate pattern**: `TurnManager` notifies `BattleController` of turn lifecycle events via `TurnDelegate`. All methods async. `_advanceTurn()` uses an iterative loop: fill queue -> pick unit -> process buffs/cells -> if dead, continue to next -> else notify `onTurnStart`. No recursive async calls.
- **AI strategy pattern**: `Unit.aiStrategy` returns an `AIStrategy` instance (default: `AggressiveAI`). AI `decideTurn()` is pure; execution happens via `BattleAPI.executeSkill()` (same path as player). Uses `UnitFaction.isHostileTo()` for faction-aware targeting. No hardcoded AI in controller.
- **Part files pattern**: `Buff`, `Skill`, `Cell` use abstract base class with implementations in `part` files. Buff implementations use `export` instead of `part`.
- **Battle scenario pattern**: `BattleScenario` describes spawns. Pass to `game.startTransitionToBattle(scenario: ...)`. `BoardComponent.initBattle` generates units.
- **Cell runtime effects**: `Cell` provides `moveCost` (default 1), `onUnitEnter(UnitState, {api})`, `onTurnStart(UnitState, {api})`. All async.
- **Buff reactive hooks**: `onDamageTaken()` returns modified damage (shields/reduction). `onDamageDealt()` fires after damage (lifesteal/chain). Called by `BattleController.damageUnit` when `attacker` provided.
- **Cost-based pathfinding**: `BoardExtension.getMovablePositions()` uses SPFA with `bestCost` map. Supports variable terrain costs and path certainty tracking through fog.
- **Dual visibility model**: Center visibility (unit rendering) vs edge visibility (fog removal). Ray-cast from source center to target center/corners. Edge check uses directional corner selection.
- **Registry pattern**: `CellRegistry` maps integer IDs to `Cell` instances for map serialization.
- **Focus system**: `BattleController.focusCell` drives selection highlight; `focusUnit` (derived) drives skill interaction and range display.
- **Async movement with pass-through**: `moveUnit()` uses `Completer` to chain `MoveToEffect` animations step-by-step. Position updates go through `TurnManager.updateUnitPosition()`. Units pass through intermediate occupied cells; only final destination occupancy blocks movement.
- **Event-driven effects**: `_BoardBattlePresenter` spawns `FloatingTextComponent` on `EffectLayer` in board-local coordinates (not viewport), so floating text moves with the board and doesn't drift during camera pan.
- **Buff iteration safety**: All loops over `unit.buffs` (in `damageUnit`, `onBuffTurnStart`, `onBuffTurnEnd`) use `List.of()` snapshot to prevent `ConcurrentModificationError` when buff hooks modify the list.
- **Two-phase mode transitions**: Exploration <-> Battle over 1.5s. Phase 1: isometric projection interpolation (factor 0<->1). Phase 2: camera pan + zoom. `AnimatableIsoDecorator` drives projection. Coordinate transform overrides on `BoardComponent` support hit-testing at any interpolation state.
- **Attribute recalculation**: `UnitState.recalculateAttributes()` resets to base -> sorts buffs by priority -> applies each -> clamps HP and AP. `currentActionPoints` clamped to `maxActionPoints` after buff changes. Triggered by `addBuff`/`removeBuff`.
- **Interaction locking**: `BattleController._locked` prevents concurrent skill execution and input during AI turns.

## Extension Guide

- **New skills**: extend `Skill` as `part` file in `lib/core/skills/`, implement `onTap(state, target, api)` using `BattleAPI` methods, return `true` if action executed. Implement `getHighlightPositions()` for range display. Add to `Unit.skills` list. Set `cost`, `cooldown`, `maxUsesPerTurn` as needed.
- **New units**: extend `Unit` in `lib/models/units/`, override `moveRange`, `skills`, `aiStrategy`, etc. Register as `BasicSoldier` pattern shows.
- **New cell types**: extend `Cell` as `part` file in `lib/models/cells/cell_base.dart`, register in `cell_registry.dart`. Override `moveCost`, `onUnitEnter()`, `onTurnStart()`. Use `SpriteCell` mixin for sprite-based or `RenderCell` mixin for canvas-based rendering.
- **New buffs**: extend `Buff` in `lib/core/buffs/`, export from `buff.dart`. Implement `apply()`, optionally override `onTurnStart()` / `onTurnEnd()` / `onDamageTaken()` / `onDamageDealt()` (all async). Set `priority` to control evaluation order.
- **New AI strategies**: extend `AIStrategy` in `lib/core/ai/`, implement `decideTurn()`. Return `AIAction` list. Assign to `Unit.aiStrategy`.
- **New presenter effects**: Add method to `BattlePresenter` interface, implement in `_BoardBattlePresenter`, call from `BattleController`.

## UI Conventions

- Prefer `StatelessWidget`; avoid `StatefulWidget` unless necessary.
- Avoid `Container`; use `DecoratedBox`, `Padding`, `Align`, `SizedBox`, `ColorBox` instead.
- All widgets should be adaptive-sized; avoid fixed dimensions unless required.
- Use centralized color definitions from `lib/common/theme.dart` and asset paths from `lib/common/assets.dart`.
- All numeric constants (durations, sizes, thresholds) go in `lib/common/constants.dart`.

## Testing

Tests are pure unit tests covering `lib/core/` logic (no Flame dependency). 126 tests total.
- `test/core/unit/unit_state_test.dart` — HealthMixin, ActionPointMixin, recalculateAttributes.
- `test/core/unit/skill_record_test.dart` — Skill history, cooldown, max uses per turn, `canUse()`.
- `test/core/unit/faction_test.dart` — `UnitFaction.isHostileTo()` full matrix: player/enemy/ally/neutral hostility, same-faction non-hostile.
- `test/core/battle/turn_manager_test.dart` — ATB progression, turn ordering, AP recovery, duplicate registration.
- `test/core/battle/turn_advance_test.dart` — Iterative turn advancement, buff-death skip, multi-death sequence, removeUnit during active turn.
- `test/core/battle/battle_integration_test.dart` — Damage chain (buff hooks, lethal damage), buff lifecycle (add/remove/snapshot safety), faction hostility, executeSkill (canUse check, AP/recording), AP clamp after recalculate.
- `test/core/buffs/buff_test.dart` — Buff application, removal, expiration, attribute effects, priority.
- `test/core/map/board_test.dart` — BFS pathfinding, vision ray-casting, path certainty.
- `test/core/map/game_map_test.dart` — Map creation, fog update, cell access, blocking properties, `GameMap.standard` with custom generator.
- `test/core/skills/skill_test.dart` — `getPositionsInRange()` manhattan distance, boundary clipping.
- `test/core/ai/simple_ai_test.dart` — AI targeting logic, manhattan distance, nearest enemy selection.
- `test/core/ai/ai_action_test.dart` — `AggressiveAI` with `isHostileTo` (targets player, ignores neutral, attacks ally), `AIUseSkill` with `AttackSkill`, move-then-attack, `canUse` maxUsesPerTurn enforcement.

## Key Dependencies

- `flame` ^1.18.0 — Game engine
- `collection` ^1.18.0 — Priority queue for pathfinding
