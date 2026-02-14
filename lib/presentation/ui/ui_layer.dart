import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../core/skills/skill.dart';
import '../../game/alebel_game.dart';

class UiLayer extends PositionComponent with HasGameReference<AlebelGame> {
  late TextComponent _infoText;
  late TurnOrderDisplay _turnOrderDisplay;
  late EndTurnButton _endTurnButton;
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
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    _updateButtonPositions();
    _endTurnButton.position = Vector2(size.x - 120, size.y - 70);
    _turnOrderDisplay.position = Vector2(size.x - 20, 20);
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

    // 更新显示的文本信息
    final selectedUnit = game.selectedUnit;
    if (selectedUnit != null) {
      _infoText.text =
          'Selected Unit: ${selectedUnit.state.unit.faction.name}\n'
          'Pos: (${selectedUnit.gridX}, ${selectedUnit.gridY})\n'
          'HP: ${selectedUnit.state.currentHp} / ${selectedUnit.state.maxHp}\n'
          'Mode: ${selectedUnit.state.currentSkill.name}';

      // Update skill buttons
      _updateSkillButtons(selectedUnit.state.unit.skills);
    } else {
      _clearSkillButtons();

      final hoveredCell = game.hoveredCell;
      if (hoveredCell != null) {
        _infoText.text = 'Hovered Cell: (${hoveredCell.gridX}, ${hoveredCell.gridY})';
      } else {
        _infoText.text = 'Alebel Game';
      }
    }
  }

  void _updateSkillButtons(List<Skill> skills) {
    // If skills changed (count or instances), recreate buttons
    // For simplicity, we check count and names.
    // Assuming skills list is stable for a unit instance for now.

    // If button count matches skill count, just update/ensure they are visible
    if (_skillButtons.length == skills.length) {
      // Assuming same order/skills
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

  // @override
  // bool containsLocalPoint(Vector2 point) {
  //   // 只有当点击到按钮时，才视为击中 UiLayer
  //   for (final button in _skillButtons) {
  //     if (button.containsPoint(point)) return true;
  //   }
  //   return false;
  // }
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
    // Current active unit
    final active = game.turnManager.activeUnit;
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
      _headerPaint.render(
        canvas,
        'Waiting...',
        Vector2(0, y),
        anchor: Anchor.topRight,
      );
      y += 25;
    }

    // Predicted units
    // We want to show next 3 units
    final nextUnits = game.turnManager.getPredictedTurnOrder(3);

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
    final isSelected = game.selectedUnit?.state.currentSkill == skill;

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
    final selectedUnit = game.selectedUnit;
    if (selectedUnit == null) return;

    print("Skill button tapped: ${skill.name}");

    // Switch skill
    final state = selectedUnit.state;
    if (state.currentSkill != skill) {
      state.currentSkill = skill;
      game.updateRangeLayer();
    } else {
      // Toggle off? Switch to Move?
      if (skill != state.unit.moveSkill) {
        state.currentSkill = state.unit.moveSkill;
        game.updateRangeLayer();
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
    print("End Turn button tapped");
    game.turnManager.endTurn();
    event.handled = true;
  }
}
