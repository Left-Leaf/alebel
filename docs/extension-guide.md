# Alebel 扩展与场景搭建指南

## 目录

- [一、类型扩展](#一类型扩展)
  - [1. 添加新 Unit](#1-添加新-unit)
  - [2. 添加新 Cell](#2-添加新-cell)
  - [3. 添加新 Buff](#3-添加新-buff)
  - [4. 添加新 Skill](#4-添加新-skill)
  - [5. 添加新 AI 策略](#5-添加新-ai-策略)
- [二、场景搭建](#二场景搭建)
  - [1. 探索场景](#1-探索场景)
  - [2. 战斗场景](#2-战斗场景)
- [三、快速参考](#三快速参考)

---

## 一、类型扩展

### 1. 添加新 Unit

**文件位置**：`lib/models/units/` 下新建独立文件

**步骤**：

1. 创建文件，继承 `Unit` 抽象类，覆写所有必需属性：

```dart
// lib/models/units/archer.dart
import 'package:flutter/material.dart';
import 'package:alebel/models/units/unit_base.dart';
import 'package:alebel/core/skills/skill.dart';

class Archer extends Unit {
  @override final int moveRange;
  @override final int visionRange;
  @override final int attackRange;
  @override final int attack;
  @override final int speed;
  @override final int maxHp;
  @override final MoveSkill moveSkill;
  @override final List<Skill> skills;

  Archer({
    required super.color,
    super.faction,
    this.moveRange = 3,
    this.visionRange = 7,
    this.attackRange = 4,
    this.attack = 8,
    this.speed = 12,
    this.maxHp = 60,
  })  : moveSkill = MoveSkill(),
        skills = [AttackSkill()];

  // 可选：覆写 AI 策略（默认为 AggressiveAI）
  // @override
  // AIStrategy get aiStrategy => const SniperAI();
}
```

2. 在 `BattleScenario` 或 `BoardComponent` 中直接使用，无需额外注册。

**必须覆写的属性**：

| 属性 | 说明 |
|---|---|
| `moveRange` | 移动范围（BFS 寻路步数上限） |
| `visionRange` | 视野范围（射线投射半径） |
| `attackRange` | 攻击范围（曼哈顿距离） |
| `attack` | 基础攻击力 |
| `speed` | 速度（决定 ATB 行动条填充速率） |
| `maxHp` | 最大生命值 |
| `moveSkill` | 移动技能实例 |
| `skills` | 技能列表 |

**可选覆写**：

| 属性 | 默认值 | 说明 |
|---|---|---|
| `aiStrategy` | `AggressiveAI()` | AI 决策策略 |

---

### 2. 添加新 Cell

**文件位置**：`lib/models/cells/` 下新建 `part` 文件

**步骤**：

1. 创建 `part` 文件，继承 `Cell`，混入 `SpriteCell`（图片渲染）或 `RenderCell`（Canvas 渲染）：

```dart
// lib/models/cells/lava_cell.dart
part of 'cell_base.dart';

class LavaCell extends Cell with RenderCell {
  const LavaCell()
      : super(
          name: 'Lava',
          blocksMovement: false,
          canStand: true,
        );

  @override
  int get moveCost => 2; // 移动代价（默认为 1）

  // 单位进入时触发
  @override
  Future<void> onUnitEnter(UnitState unit, {BattleAPI? api}) async {
    if (api != null) {
      await api.damageUnit(unit, 10);
    }
  }

  // 单位回合开始时触发
  @override
  Future<void> onTurnStart(UnitState unit, {BattleAPI? api}) async {
    if (api != null) {
      await api.damageUnit(unit, 5);
    }
  }

  // RenderCell 要求实现 render
  @override
  void render(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFF5722);
    canvas.drawRect(Offset.zero & size, paint);
  }
}
```

如果使用图片渲染，改用 `SpriteCell`：

```dart
class SandCell extends Cell with SpriteCell {
  const SandCell() : super(name: 'Sand');

  @override
  int get moveCost => 2;

  @override
  String get imagePath => 'sand.jpg'; // assets/images/ 下的图片
}
```

2. 在 `cell_base.dart` 中添加 `part` 声明：

```dart
part 'lava_cell.dart';
```

3. 在 `CellRegistry` 中注册，分配唯一整数 ID（`lib/models/cells/cell_registry.dart` 或 `AlebelGame.onLoad`）：

```dart
cellRegistry.register({
  0: const GroundCell(),
  1: const WallCell(),
  2: const WaterCell(),
  3: const ForestCell(),
  4: const LavaCell(), // 新增
});
```

4. 在地图矩阵中使用该 ID 放置地块。

**构造函数参数**：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `name` | 必填 | 地块名称 |
| `blocksVision` | `false` | 是否阻挡视线 |
| `blocksMovement` | `false` | 是否阻挡移动 |
| `canStand` | `true` | 单位是否可以停留 |

**可选覆写**：

| 方法/属性 | 默认行为 | 说明 |
|---|---|---|
| `moveCost` | `1` | 移动消耗（影响寻路代价） |
| `onUnitEnter()` | 空 | 单位进入时的效果 |
| `onTurnStart()` | 空 | 站在该格的单位回合开始时的效果 |

**渲染 Mixin 二选一**：

| Mixin | 用法 |
|---|---|
| `SpriteCell` | 覆写 `imagePath` 返回图片路径 |
| `RenderCell` | 覆写 `render(Canvas, Size)` 自定义绘制 |

---

### 3. 添加新 Buff

**文件位置**：`lib/core/buffs/` 下新建独立文件

**步骤**：

1. 创建文件，继承 `Buff` 抽象类：

```dart
// lib/core/buffs/shield_buff.dart
import 'package:alebel/core/buffs/buff.dart';
import 'package:alebel/core/unit/unit_state.dart';
import 'package:alebel/core/battle/battle_api.dart';

class ShieldBuff extends Buff {
  final int damageReduction;

  @override
  String get id => 'shield';
  @override
  String get name => 'Shield';
  @override
  String get description => 'Reduces damage taken by $damageReduction';
  @override
  int get priority => 0; // 低数值 = 先计算

  ShieldBuff({required this.damageReduction, required super.duration});

  // 修改单位属性（recalculateAttributes 时调用）
  @override
  void apply(UnitState state) {
    // 本 buff 不修改属性，仅通过钩子减伤
  }

  // 受击时修改伤害值
  @override
  Future<int> onDamageTaken(
    UnitState state,
    int damage, {
    UnitState? attacker,
    BattleAPI? api,
  }) async {
    return (damage - damageReduction).clamp(0, damage);
  }
}
```

2. 在 `lib/core/buffs/buff.dart` 中添加 export：

```dart
export 'shield_buff.dart';
```

3. 通过 `BattleAPI.addBuff()` 在运行时添加：

```dart
await api.addBuff(targetUnit, ShieldBuff(damageReduction: 5, duration: 3));
```

**必须实现**：

| 属性/方法 | 说明 |
|---|---|
| `id` | 唯一标识字符串 |
| `name` | 显示名称 |
| `description` | 描述文本 |
| `apply(state)` | 属性修改逻辑（属性重算时调用） |

**可选覆写的钩子**：

| 钩子 | 触发时机 | 返回值 | 用途示例 |
|---|---|---|---|
| `onTurnStart(state, {api})` | 单位回合开始 | void | 中毒伤害、回复 |
| `onTurnEnd(state, {api})` | 单位回合结束 | `bool`（true=到期移除） | 持续时间递减 |
| `onDamageTaken(state, damage, {attacker, api})` | 受到伤害时 | 修改后的伤害值 | 减伤、护盾 |
| `onDamageDealt(state, target, damage, {api})` | 造成伤害后 | void | 吸血、连锁伤害 |

**priority 规则**：数值越小越先计算。属性修改类 buff（如攻击加成）建议用 `priority = 10`，基础效果用 `priority = 0`。

---

### 4. 添加新 Skill

**文件位置**：`lib/core/skills/` 下新建 `part` 文件

**步骤**：

1. 创建 `part` 文件，继承 `Skill` 抽象类：

```dart
// lib/core/skills/heal_skill.dart
part of 'skill.dart';

class HealSkill extends Skill {
  @override
  String get name => 'Heal';

  @override
  int get cost => 2; // AP 消耗

  @override
  int get cooldown => 2; // 回合冷却

  @override
  int get maxUsesPerTurn => 1; // 每回合最多使用次数（-1 = 无限）

  final int healAmount;
  HealSkill({this.healAmount = 20});

  // 范围高亮显示
  @override
  List<({Position pos, Color color})> getHighlightPositions(
    UnitState state,
    SkillContext ctx,
  ) {
    return Skill.getPositionsInRange(
      (x: state.x, y: state.y),
      3, // 施法范围
      mapWidth: ctx.gameMap.width,
      mapHeight: ctx.gameMap.height,
    ).map((pos) => (pos: pos, color: const Color(0xFF4CAF50))).toList();
  }

  // 点击目标格时的执行逻辑
  @override
  Future<bool> onTap(UnitState state, Position target, BattleAPI api) async {
    if (api.activeUnit != state) return false;

    final targetUnit = api.getUnitAt(target.x, target.y);
    if (targetUnit == null) return false;

    // 只能治疗非敌对单位
    if (state.unit.faction.isHostileTo(targetUnit.unit.faction)) return false;

    // 检查距离
    final distance = (target.x - state.x).abs() + (target.y - state.y).abs();
    if (distance > 3) return false;

    await api.healUnit(targetUnit, healAmount);
    return true; // 返回 true 表示行动已执行（消耗 AP、记录使用）
  }
}
```

2. 在 `skill.dart` 中添加 `part` 声明：

```dart
part 'heal_skill.dart';
```

3. 在 Unit 定义的 `skills` 列表中引用：

```dart
@override
final List<Skill> skills = [AttackSkill(), HealSkill()];
```

**必须实现**：

| 方法 | 说明 |
|---|---|
| `onTap(state, target, api)` | 点击目标时执行。返回 `true` 表示行动已执行，`false` 表示仅交互（如聚焦） |
| `getHighlightPositions(state, ctx)` | 返回需要高亮的格子及颜色，用于范围显示 |

**可选覆写的属性**：

| 属性 | 默认值 | 说明 |
|---|---|---|
| `cost` | `0` | AP 消耗 |
| `cooldown` | `0` | 使用后的冷却回合数 |
| `maxUsesPerTurn` | `-1` | 每回合最多使用次数（-1 = 无限） |

**可用的 BattleAPI 方法**：

| 方法 | 用途 |
|---|---|
| `api.damageUnit(target, amount, attacker: state)` | 造成伤害 |
| `api.healUnit(target, amount)` | 治疗 |
| `api.moveUnit(state, path)` | 移动（沿路径动画） |
| `api.addBuff(target, buff)` | 添加 buff |
| `api.removeBuff(target, buff)` | 移除 buff |
| `api.setFocus(position)` | 设置焦点格 |
| `api.setPreview(state, position)` | 设置预览位置（移动预览） |
| `api.clearPreview(state)` | 清除预览 |
| `api.switchSkill(state, skill)` | 切换当前技能 |

**工具方法**：

```dart
// 获取曼哈顿距离范围内的所有格子
Skill.getPositionsInRange(center, range, mapWidth: w, mapHeight: h);
```

---

### 5. 添加新 AI 策略

**文件位置**：`lib/core/ai/` 下新建文件

**步骤**：

1. 创建文件，实现 `AIStrategy` 接口：

```dart
// lib/core/ai/defensive_ai.dart
import 'package:alebel/core/ai/simple_ai.dart';

class DefensiveAI implements AIStrategy {
  const DefensiveAI();

  @override
  List<AIAction> decideTurn(UnitState unit, AIContext ctx) {
    final actions = <AIAction>[];

    // 自定义决策逻辑...
    // 返回 AIAction 列表：AIMove(path) 和 AIUseSkill(skill, target)

    return actions;
  }
}
```

2. 在 Unit 定义中覆写 `aiStrategy`：

```dart
@override
AIStrategy get aiStrategy => const DefensiveAI();
```

**可用的 AIAction 类型**：

| 类型 | 构造 | 说明 |
|---|---|---|
| `AIMove` | `AIMove(path)` | 沿路径移动 |
| `AIUseSkill` | `AIUseSkill(skill, target)` | 对目标使用技能 |

**AIContext 提供的查询**：

| 属性/方法 | 说明 |
|---|---|
| `ctx.gameMap` | 地图实例 |
| `ctx.units` | 所有存活单位列表 |
| `ctx.getUnitAt(x, y)` | 查询指定位置的单位 |

---

## 二、场景搭建

### 1. 探索场景

探索场景的初始化在 `BoardComponent.onLoad()` 中完成，核心是三件事：**建地图、放角色、开迷雾**。

#### 1.1 创建地图

地图由整数矩阵构成，每个整数对应 `CellRegistry` 中注册的 Cell ID：

```dart
// 方式 A：手写矩阵（精确控制每个格子）
// matrix[y][x] 行优先，内部自动转为列优先存储
final matrix = [
  [1, 1, 1, 1, 1, 1, 1, 1],
  [1, 0, 0, 3, 0, 0, 0, 1],
  [1, 0, 0, 0, 0, 2, 0, 1],
  [1, 0, 3, 0, 0, 2, 0, 1],
  [1, 1, 1, 1, 1, 1, 1, 1],
];
final map = GameMap.fromMatrix(matrix, cellRegistry);
```

```dart
// 方式 B：标准地图 + 自定义生成器（程序化生成）
final map = GameMap.standard(
  cellRegistry,
  size: 40,             // 地图尺寸
  border: 2,            // 边界墙壁宽度
  generator: (x, y, size, border) {
    // 边界 → 墙壁
    if (x < border || x >= size - border ||
        y < border || y >= size - border) return 1;
    // 中心区域 → 湖泊
    if ((x - size ~/ 2).abs() + (y - size ~/ 2).abs() < 4) return 2;
    // 随机散布 → 森林
    if ((x * 7 + y * 13) % 10 == 0) return 3;
    // 其余 → 地面
    return 0;
  },
);
```

不传 `generator` 则使用默认生成器（边界墙壁 + 内部全地面）。

#### 1.2 放置探索角色

探索模式使用轻量的 `ExplorerComponent`，只引用不可变的 `Unit` 定义，不涉及 `UnitState`：

```dart
final playerDef = BasicSoldier(color: Colors.blue, faction: UnitFaction.player);
explorer = ExplorerComponent(unit: playerDef, gridX: 5, gridY: 5);
unitLayer.add(explorer!);
```

#### 1.3 初始化迷雾

`FogController` 通过闭包获取视野来源。探索模式下只有探索者一个来源：

```dart
_fogController = FogController(
  gameMap: gameMap,
  getVisionSources: () => [
    (x: explorer!.gridX, y: explorer!.gridY, range: explorer!.unit.visionRange),
  ],
);
_fogController.updateFog();
```

探索者每走一步，`ExplorationController` 自动调用 `board.updateFog()` 重新计算迷雾。

#### 1.4 探索模式移动

`ExplorationController` 处理 WASD/方向键输入，每次移动前验证：

- 目标位置在地图范围内
- 目标格子 `blocksMovement == false`

验证通过后更新 `explorer.gridX/Y`，播放 `MoveToEffect` 动画，完成后更新迷雾和摄像机跟随。

---

### 2. 战斗场景

#### 2.1 整体流程

```
探索模式
  │
  ▼
startTransitionToBattle(scenario)
  │
  ▼
两阶段过渡动画（1.5s）
  ├── 阶段 1：等角投影插值（俯视 → 等角）
  └── 阶段 2：摄像机平移 + 缩放
  │
  ▼
initBattle()
  ├── 移除探索者
  ├── 生成战斗单位
  ├── 挂载 BattleController
  ├── 启动回合系统
  └── 更新战斗迷雾
  │
  ▼
战斗模式
  │
  ▼（战斗结束）
teardownBattle()
  ├── 清理 BattleController
  ├── 移除所有战斗单位
  ├── 在玩家最终位置重建探索者
  └── 恢复探索迷雾
  │
  ▼
探索模式
```

#### 2.2 定义战斗场景

```dart
final scenario = BattleScenario(
  enemies: [
    UnitSpawn(
      unit: BasicSoldier(
        color: Colors.red,
        faction: UnitFaction.enemy,
        attack: 15,
      ),
      offset: (x: 4, y: 4), // 相对于玩家位置的偏移
    ),
    UnitSpawn(
      unit: BasicSoldier(
        color: Colors.red,
        faction: UnitFaction.enemy,
      ),
      offset: (x: -3, y: 5),
    ),
  ],
  allies: [ // 可选，默认为空
    UnitSpawn(
      unit: BasicSoldier(
        color: Colors.green,
        faction: UnitFaction.ally,
      ),
      offset: (x: 1, y: 0),
    ),
  ],
);
```

`offset` 是相对于玩家当前位置的偏移。例如玩家在 `(5, 5)`，`offset: (x: 4, y: 4)` 的敌人会生成在 `(9, 9)`。

#### 2.3 触发战斗

```dart
game.startTransitionToBattle(scenario: scenario);
```

#### 2.4 initBattle 内部流程

`BoardComponent.initBattle()` 在过渡动画完成后自动调用：

```
① 记录探索者状态
   startX = explorer.gridX
   startY = explorer.gridY
   playerDef = explorer.unit
       │
       ▼
② 移除探索者组件
   unitLayer.remove(explorer)
   explorer = null
       │
       ▼
③ 生成玩家战斗单位（原位）
   playerUnit = _addUnit(startX, startY, playerDef)
       │
       ▼
④ 生成盟友（玩家位置 + 偏移）
   for spawn in scenario.allies:
     _addUnit(startX + offset.x, startY + offset.y, spawn.unit)
       │
       ▼
⑤ 生成敌人（玩家位置 + 偏移）
   for spawn in scenario.enemies:
     _addUnit(startX + offset.x, startY + offset.y, spawn.unit)
       │
       ▼
⑥ 创建并挂载 BattleController
   controller.setup()  → 设置 turnManager.delegate
       │
       ▼
⑦ 启动回合系统 + 更新迷雾
   turnManager.startBattle()
   updateFog()
```

#### 2.5 _addUnit：单位生成与落位

这是角色从定义到上场的核心方法：

```dart
UnitComponent _addUnit(int x, int y, Unit unitDef) {
  // 1. 从不可变 Unit 定义 → 创建可变 UnitState（运行时战斗状态）
  final unitState = UnitState(unit: unitDef, x: x, y: y);

  // 2. 创建视觉组件
  final unitComponent = UnitComponent(state: unitState);

  // 3. 添加到渲染层（UnitLayer）
  unitLayer.addUnit(unitComponent);

  // 4. 注册到回合管理器
  turnManager.registerUnit(unitState);

  return unitComponent;
}
```

#### 2.6 TurnManager.registerUnit：回合系统注册

```dart
void registerUnit(UnitState unit) {
  _units.add(unit);

  // 建立空间索引（O(1) 位置查询）
  _positionIndex[(x: unit.x, y: unit.y)] = unit;

  // 行动条随机初始化，避免同速度单位同时行动
  unit.actionGauge = (unit.currentSpeed * 5).clamp(0, maxGauge * 0.5);
}
```

#### 2.7 回合系统启动

`turnManager.startBattle()` 调用 `_advanceTurn()` 迭代循环，找到第一个行动的单位：

```
┌──→ _fillActionQueue()
│      所有单位按速度填充行动条
│      行动条 >= 1000 的单位入队（按速度降序）
│           │
│           ▼
│      出队第一个单位
│           │
│           ▼
│      已死亡？ ──是──→ 跳过，继续循环 ─┐
│           │ 否                         │
│           ▼                            │
│      beginTurnRecord()                 │
│      onBuffTurnStart()  ← buff 回合效果  │
│      onCellTurnStart()  ← 地块回合效果   │
│           │                            │
│           ▼                            │
│      效果致死？ ──是──→ onUnitDeath ────┘
│           │ 否
│           ▼
│      onTurnStart()
│        ├── 玩家单位 → 聚焦，等待玩家操作
│        └── AI 单位 → 执行 AI 策略
│           │
│           ▼
└──── 等待 endTurn() 调用 ──→ 下一轮循环
```

#### 2.8 战斗迷雾

战斗模式下，视野来源变为所有玩家阵营存活单位（多来源合并）：

```dart
List<({int x, int y, int range})> _computeVisionSources() {
  return unitLayer.units
      .where((u) => u.faction == UnitFaction.player)
      .map((u) => (x: u.gridX, y: u.gridY, range: u.state.currentVisionRange))
      .toList();
}
```

#### 2.9 战斗结束与清理

`teardownBattle()` 执行逆向流程：

```
① 清理 BattleController 和特效层
② 记录玩家最终位置 (endX, endY)
③ 移除所有战斗单位（从 TurnManager + UnitLayer）
④ 在玩家最终位置重建 ExplorerComponent
⑤ 重新计算迷雾（回到单来源模式）
```

---

## 三、快速参考

### 文件组织与注册方式

| 扩展类型 | 基类 | 文件组织 | 注册方式 |
|---|---|---|---|
| Unit | `Unit` | 独立文件 `lib/models/units/` | 直接在 `BattleScenario` 中引用 |
| Cell | `Cell` | `part` 文件 `lib/models/cells/` | `CellRegistry.register()` 分配整数 ID |
| Buff | `Buff` | 独立文件 `lib/core/buffs/` + export | 运行时通过 `BattleAPI.addBuff()` 添加 |
| Skill | `Skill` | `part` 文件 `lib/core/skills/` | 在 `Unit.skills` 列表中引用 |
| AI 策略 | `AIStrategy` | 独立文件 `lib/core/ai/` | 在 `Unit.aiStrategy` 中引用 |
| Map | `GameMap` | 工厂构造函数 | `fromMatrix` 或 `standard` |

### 探索 vs 战斗模式对比

| 方面 | 探索模式 | 战斗模式 |
|---|---|---|
| 角色表示 | `ExplorerComponent`（轻量，只有 `Unit` 引用） | `UnitComponent` + `UnitState`（完整战斗状态） |
| 地图 | `GameMap` 实例 | 同一个 `GameMap`，共享不重建 |
| 迷雾来源 | 探索者 1 个 | 所有玩家阵营存活单位 |
| 位置管理 | `explorer.gridX/Y` 直接修改 | `TurnManager.updateUnitPosition()` 维护空间索引 |
| 输入方式 | `ExplorationController`（WASD/方向键） | `BattleController`（点击格子） |
| 回合系统 | 无 | `TurnManager` ATB 循环 |
| 视角 | 俯视（isoFactor = 0） | 等角投影（isoFactor = 1） |
| 缩放 | `explorationZoom = 2.0` | `battleZoom = 1.0` |

### 关键设计原则

- **静态 vs 运行时分离**：`Unit`/`Cell` 是不可变配置，`UnitState`/`CellState` 是可变运行时数据
- **BattleAPI 模式**：技能通过 `BattleAPI` 接口执行效果，不直接操作状态
- **空间索引一致性**：所有位置变更必须通过 `TurnManager.updateUnitPosition()`
- **Buff 快照安全**：遍历 `unit.buffs` 时使用 `List.of()` 防止并发修改
