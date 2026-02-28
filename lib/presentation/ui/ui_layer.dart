import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../core/game_mode.dart';
import '../../core/skills/skill.dart';
import '../../game/alebel_game.dart';

class UiLayer extends PositionComponent with HasGameReference<AlebelGame> {
  late TextComponent _infoText;
  late TurnOrderDisplay _turnOrderDisplay;
  late EndTurnButton _endTurnButton;
  late DebugModeButton _debugModeButton;
  final List<SkillButton> _skillButtons = [];

  @override
  Future<void> onLoad() async {
    // 设置 UI 的大小为视口大小
    size = game.camera.viewport.size;

    _infoText = TextComponent(
      text: 'Alebel HUD',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2))],
        ),
      ),
    )..position = Vector2(20, 20);

    add(_infoText);

    _turnOrderDisplay = TurnOrderDisplay();
    add(_turnOrderDisplay);

    _endTurnButton = EndTurnButton();
    add(_endTurnButton);

    _debugModeButton = DebugModeButton();
    add(_debugModeButton);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    _updateButtonPositions();
    _endTurnButton.position = Vector2(size.x - 120, size.y - 70);
    _turnOrderDisplay.position = Vector2(size.x - 20, 20);
    _debugModeButton.position = Vector2((size.x - _debugModeButton.width) / 2, 20);
  }

  void _updateButtonPositions() {
    double xOffset = 20;
    for (final button in _skillButtons) {
      button.position = Vector2(xOffset, size.y - 70);
      xOffset += 120; // 100 width + 20 gap
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (game.mode == GameMode.exploration) {
      _infoText.text = 'Exploration Mode';
      _clearSkillButtons();
      return;
    }

    // 对战模式 UI 更新
    final unit = game.board.focusUnit;
    if (unit != null) {
      _infoText.text =
          'Selected Unit: ${unit.state.unit.faction.name}\n'
          'Pos: (${unit.gridX}, ${unit.gridY})\n'
          'HP: ${unit.state.currentHp} / ${unit.state.maxHp}\n'
          'AP: ${unit.state.currentActionPoints} / ${unit.state.maxActionPoints}\n'
          'Mode: ${unit.state.focusSkill.name}';

      _updateSkillButtons(unit.state.unit.skills);
    } else {
      _clearSkillButtons();

      final hoveredCell = game.board.hoveredCell;
      if (hoveredCell != null) {
        _infoText.text = 'Hovered Cell: (${hoveredCell.gridX}, ${hoveredCell.gridY})';
      } else {
        _infoText.text = 'Alebel Game';
      }
    }
  }

  void _updateSkillButtons(List<Skill> skills) {
    if (_skillButtons.length == skills.length) {
      return;
    }

    _clearSkillButtons();

    for (final skill in skills) {
      final button = SkillButton(skill: skill);
      add(button);
      _skillButtons.add(button);
    }
    _updateButtonPositions();
  }

  void _clearSkillButtons() {
    for (final button in _skillButtons) {
      remove(button);
    }
    _skillButtons.clear();
  }
}

class TurnOrderDisplay extends PositionComponent with HasGameReference<AlebelGame> {
  final _headerPaint = TextPaint(
    style: const TextStyle(
      color: Colors.yellowAccent,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2))],
    ),
  );

  final _nextPaint = TextPaint(
    style: const TextStyle(
      color: Colors.white70,
      fontSize: 14,
      shadows: [Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1))],
    ),
  );

  @override
  void render(Canvas canvas) {
    if (game.mode != GameMode.battle) return;

    // Current active unit
    final active = game.board.turnManager.activeUnit;
    double y = 0;

    if (active != null) {
      _headerPaint.render(
        canvas,
        'Current: ${active.unit.faction.name}',
        Vector2(0, y),
        anchor: Anchor.topRight,
      );
      y += 25;
    } else {
      _headerPaint.render(canvas, 'Waiting...', Vector2(0, y), anchor: Anchor.topRight);
      y += 25;
    }

    // Predicted units
    final nextUnits = game.board.turnManager.getPredictedTurnOrder(3);

    for (int i = 0; i < nextUnits.length; i++) {
      final u = nextUnits[i];
      _nextPaint.render(
        canvas,
        'Next: ${u.unit.faction.name}',
        Vector2(0, y),
        anchor: Anchor.topRight,
      );
      y += 20;
    }
  }
}

class SkillButton extends PositionComponent with TapCallbacks, HasGameReference<AlebelGame> {
  final Skill skill;
  final _paint = Paint()..color = Colors.blueGrey;
  final _selectedPaint = Paint()..color = Colors.orange;
  final _textPaint = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
  );

  SkillButton({required this.skill}) {
    size = Vector2(100, 50);
  }

  @override
  void render(Canvas canvas) {
    if (game.mode != GameMode.battle) return;

    final isSelected = game.board.focusUnit?.state.focusSkill == skill;

    // 绘制按钮背景
    final rect = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRect(rect, isSelected ? _selectedPaint : _paint);

    // 绘制边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, borderPaint);

    // 绘制文字
    _textPaint.render(canvas, skill.name, Vector2(width / 2, height / 2), anchor: Anchor.center);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.mode != GameMode.battle) return;

    final focusUnit = game.board.focusUnit;
    if (focusUnit == null) return;

    final state = focusUnit.state;
    if (state.focusSkill != skill) {
      state.focusSkill = skill;
      game.board.updateRangeLayer();
    } else {
      if (skill != state.unit.moveSkill) {
        state.focusSkill = state.unit.moveSkill;
        game.board.updateRangeLayer();
      }
    }

    event.handled = true;
  }
}

class EndTurnButton extends PositionComponent with TapCallbacks, HasGameReference<AlebelGame> {
  final _paint = Paint()..color = Colors.redAccent;
  final _textPaint = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
  );

  EndTurnButton() {
    size = Vector2(100, 50);
  }

  @override
  void render(Canvas canvas) {
    if (game.mode != GameMode.battle) return;

    final rect = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRect(rect, _paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, borderPaint);

    _textPaint.render(canvas, 'End Turn', Vector2(width / 2, height / 2), anchor: Anchor.center);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.mode != GameMode.battle) return;

    print("End Turn button tapped");
    game.board.turnManager.endTurn();
    event.handled = true;
  }
}

class DebugModeButton extends PositionComponent
    with TapCallbacks, HasGameReference<AlebelGame> {
  final _paint = Paint()..color = Colors.deepPurple;
  final _textPaint = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
  );

  DebugModeButton() {
    size = Vector2(120, 40);
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRect(rect, _paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, borderPaint);

    final label = game.mode == GameMode.exploration ? 'To Battle' : 'To Explore';
    _textPaint.render(canvas, label, Vector2(width / 2, height / 2), anchor: Anchor.center);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.isTransitioning) return;

    if (game.mode == GameMode.exploration) {
      game.startTransitionToBattle();
    } else {
      game.startTransitionToExploration();
    }
    event.handled = true;
  }
}
