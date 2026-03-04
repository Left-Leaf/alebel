import 'dart:typed_data';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Color;

import '../common/constants.dart';
import '../common/theme.dart';
import '../core/battle/battle_presenter.dart';
import '../core/buffs/buff.dart';
import '../core/unit/unit_state.dart';
import '../presentation/components/cell_component.dart';
import '../presentation/components/floating_text.dart';
import '../presentation/layers/effect_layer.dart';
import '../presentation/ui/ui_layer.dart';

/// BattlePresenter 的 presentation 层实现。
///
/// 将飘字生成在棋盘本地坐标系（EffectLayer 内），
/// 使其随棋盘一起变换，避免相机移动时飘字偏移。
///
/// 通过构造函数注入依赖，避免访问 BoardComponent 私有字段。
class BoardBattlePresenter implements BattlePresenter {
  final EffectLayer effectLayer;
  final double Function() getIsoFactor;
  final (double, double, double, double) Function() getMatrixComponents;
  final UiLayer? Function() findUiLayer;

  BoardBattlePresenter({
    required this.effectLayer,
    required this.getIsoFactor,
    required this.getMatrixComponents,
    required this.findUiLayer,
  });

  @override
  Future<void> showDamage(UnitState unit, int damage) async {
    _spawnFloatingText(unit.x, unit.y, '-$damage',
        color: AlebelTheme.damageText, fontSize: 16);
  }

  @override
  Future<void> showHeal(UnitState unit, int amount) async {
    _spawnFloatingText(unit.x, unit.y, '+$amount',
        color: AlebelTheme.healText, fontSize: 16);
  }

  @override
  Future<void> showDeath(UnitState unit) async {
    _spawnFloatingText(unit.x, unit.y, 'DEAD',
        color: AlebelTheme.deathText, fontSize: 18);
  }

  @override
  Future<void> showBuffApplied(UnitState unit, Buff buff) async {
    _spawnFloatingText(unit.x, unit.y, '+${buff.name}',
        color: AlebelTheme.buffAppliedText, fontSize: 12, offsetY: -10);
  }

  @override
  Future<void> showBuffRemoved(UnitState unit, Buff buff) async {
    _spawnFloatingText(unit.x, unit.y, '-${buff.name}',
        color: AlebelTheme.buffRemovedText, fontSize: 12, offsetY: -10);
  }

  @override
  Future<void> showBattleEnd(bool playerWon) async {
    final uiLayer = findUiLayer();
    if (uiLayer != null) {
      uiLayer.add(BattleEndOverlay(playerWon: playerWon, viewportSize: uiLayer.size));
    }
  }

  void _spawnFloatingText(int gridX, int gridY, String text, {
    required Color color, double fontSize = 14, double offsetY = 0,
  }) {
    // 棋盘本地坐标（格子中心偏右上）
    final position = Vector2(
      (gridX + 0.5) * CellComponent.cellSize + 20,
      (gridY + 0.5) * CellComponent.cellSize - 20 + offsetY,
    );

    // 计算反向等角投影矩阵和屏幕竖直向上的漂浮方向
    Float64List? counterTransform;
    Vector2? floatDirection;

    if (getIsoFactor() > 0.001) {
      final (m00, m01, m10, m11) = getMatrixComponents();
      final det = m00 * m11 - m01 * m10;
      if (det.abs() > 0.0001) {
        // M⁻¹ — 抵消父级等角变换，使文字保持俯视平面
        counterTransform = Float64List.fromList([
          m11 / det, -m10 / det, 0, 0,
          -m01 / det, m00 / det, 0, 0,
          0, 0, 1, 0,
          0, 0, 0, 1,
        ]);
        // M⁻¹ × (0, -d) — 棋盘本地方向，经等角投影后在屏幕上竖直向上
        final d = GameConstants.floatDistance;
        floatDirection = Vector2(m01 * d / det, -m00 * d / det);
      }
    }

    effectLayer.add(FloatingTextComponent(
      text: text,
      color: color,
      fontSize: fontSize,
      position: position,
      counterTransform: counterTransform,
      floatDirection: floatDirection,
    ));
  }
}
