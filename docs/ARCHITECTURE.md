# Architecture Documentation

## Directory Structure

The project follows a layered architecture to separate concerns between core logic, data models, and presentation (UI/Rendering).

```
lib/
├── core/                  # Core game logic and state management
│   ├── battle/            # Turn-based battle system (TurnManager)
│   ├── map/               # Map logic, pathfinding, cell state
│   ├── skills/            # Skill system logic
│   └── unit/              # Runtime unit state
├── models/                # Static data definitions
│   ├── cells/             # Cell configurations and registry
│   └── units/             # Unit definitions
├── presentation/          # Flame components and UI
│   ├── components/        # Individual game entity components (UnitComponent, CellComponent)
│   ├── layers/            # Map layers (Grid, Units, Fog, Range)
│   └── ui/                # HUD and overlays
└── game/                  # Main Game loop and initialization
```

## Key Systems

### 1. Map System (`core/map`)
- **GameMap**: Manages the grid of cells.
- **Board**: Interface for pathfinding and visibility.
- **CellState**: Represents the runtime state of a cell (fog, visibility).
- **Cell**: Represents the static configuration of a cell type (terrain).

### 2. Unit System (`core/unit` & `models/units`)
- **Unit**: Abstract base class for unit definitions (stats, faction).
- **UnitState**: Represents the runtime state of a unit (position, current HP, cooldowns).
- **UnitComponent**: Renders the unit on screen based on UnitState.

### 3. Skill System (`core/skills`)
- **Skill**: Abstract base class for abilities.
- **MoveSkill**: Handles movement logic and range calculation.
- **AttackSkill**: Handles attack logic and range calculation.

### 4. Battle System (`core/battle`)
- **TurnManager**: Manages the flow of the game (Player Turn, Enemy Turn).
