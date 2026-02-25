import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// Applies standard isometric projection to all children.
///
/// The projection matrix transforms the internal 2D plane:
/// ```
/// x' =  x·cos(30°) - y·cos(30°)
/// y' =  x·sin(30°) + y·sin(30°)
/// ```
///
/// Children use normal 2D coordinates; they will be rendered with
/// isometric projection automatically.
class IsometricComponent extends PositionComponent {
  static const double cos30 = 0.8660254037844387; // √3/2
  static const double sin30 = 0.5;
  // 1/√3, used for inverse isometric transform
  static const double _invCos30 = 0.5773502691896258;

  IsometricComponent({
    super.position,
    super.anchor,
    super.priority,
    super.children,
    super.key,
  }) {
    decorator.addLast(_IsometricDecorator());
  }

  /// Projects a 2D point through the isometric transformation.
  static Vector2 project(double x, double y) {
    return Vector2(x * cos30 - y * cos30, x * sin30 + y * sin30);
  }

  /// Returns the minimum axis-aligned bounding box size for a
  /// [width]×[height] rectangle after isometric projection.
  ///
  /// For corners (0,0), (w,0), (w,h), (0,h) projected isometrically:
  /// - Bounding box width  = (w + h) × cos(30°) = (w + h) × √3/2
  /// - Bounding box height = (w + h) × sin(30°) = (w + h) × 1/2
  static Vector2 projectedBoundingBoxSize(double width, double height) {
    return Vector2(
      (width + height) * cos30,
      (width + height) * sin30,
    );
  }

  // ------------------------------------------------------------------
  // Coordinate transform overrides
  //
  // The Decorator only affects rendering. Flame's event hit-testing uses
  // parentToLocal / toLocal / localToParent / positionOf which delegate
  // to Transform2D (position/angle/scale only). We must inject the
  // inverse isometric matrix so that pointer events land on the correct
  // pre-projection children.
  //
  // Isometric matrix M and its inverse M⁻¹:
  //   M  = [ cos30  -cos30 ]    M⁻¹ = [  1/√3   1 ]
  //        [ sin30   sin30 ]          [ -1/√3   1 ]
  // ------------------------------------------------------------------

  /// Parent space → local (pre-isometric) space.
  /// Used by [componentsAtLocation] for event hit-testing.
  @override
  Vector2 parentToLocal(Vector2 point, {Vector2? output}) {
    final projected = super.parentToLocal(point, output: output);
    return _undoIso(projected);
  }

  /// Same conversion used by [absoluteToLocal] → [containsPoint].
  @override
  Vector2 toLocal(Vector2 point) {
    return _undoIso(super.toLocal(point));
  }

  /// Local (pre-isometric) space → parent space.
  @override
  Vector2 localToParent(Vector2 point, {Vector2? output}) {
    return super.localToParent(_applyIso(point), output: output);
  }

  /// Local (pre-isometric) space → parent space (alias used by
  /// [absolutePositionOf]).
  @override
  Vector2 positionOf(Vector2 point) {
    return super.positionOf(_applyIso(point));
  }

  /// Apply the inverse isometric matrix in-place and return the vector.
  Vector2 _undoIso(Vector2 v) {
    final x = v.x * _invCos30 + v.y;
    final y = -v.x * _invCos30 + v.y;
    v.setValues(x, y);
    return v;
  }

  /// Apply the forward isometric matrix, returning a new vector
  /// (does not mutate [v] — callers may still need the original).
  Vector2 _applyIso(Vector2 v) {
    return Vector2(
      v.x * cos30 - v.y * cos30,
      v.x * sin30 + v.y * sin30,
    );
  }
}

class _IsometricDecorator extends Decorator {
  // Column-major 4×4 matrix for isometric projection:
  //
  // | cos30  -cos30  0  0 |
  // | sin30   sin30  0  0 |
  // |   0       0    1  0 |
  // |   0       0    0  1 |
  static final Float64List _isoMatrix = Float64List.fromList([
    0.8660254037844387, 0.5, 0, 0,
    -0.8660254037844387, 0.5, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  ]);

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    canvas.save();
    canvas.transform(_isoMatrix);
    draw(canvas);
    canvas.restore();
  }
}
