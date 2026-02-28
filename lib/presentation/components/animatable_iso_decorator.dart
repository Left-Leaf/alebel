import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/rendering.dart';

import 'isometric_component.dart';

/// A [Decorator] that linearly interpolates between identity (top-down) and
/// isometric projection based on [factor].
///
/// - `factor == 0.0` → identity matrix (top-down view)
/// - `factor == 1.0` → full isometric projection
class AnimatableIsoDecorator extends Decorator {
  double _factor;

  double get factor => _factor;
  set factor(double value) {
    _factor = value.clamp(0.0, 1.0);
    _updateMatrix();
  }

  final Float64List _matrix = Float64List(16);

  AnimatableIsoDecorator({double factor = 0.0}) : _factor = factor {
    _updateMatrix();
  }

  void _updateMatrix() {
    final f = _factor;

    // Interpolated values:
    // m00 = 1 + f*(cos30 - 1)    m01 = f*(-cos30)
    // m10 = f*sin30               m11 = 1 + f*(sin30 - 1)
    final m00 = 1.0 + f * (IsometricComponent.cos30 - 1.0);
    final m01 = f * (-IsometricComponent.cos30);
    final m10 = f * IsometricComponent.sin30;
    final m11 = 1.0 + f * (IsometricComponent.sin30 - 1.0);

    // Column-major 4x4 matrix
    _matrix[0] = m00;
    _matrix[1] = m10;
    _matrix[2] = 0;
    _matrix[3] = 0;

    _matrix[4] = m01;
    _matrix[5] = m11;
    _matrix[6] = 0;
    _matrix[7] = 0;

    _matrix[8] = 0;
    _matrix[9] = 0;
    _matrix[10] = 1;
    _matrix[11] = 0;

    _matrix[12] = 0;
    _matrix[13] = 0;
    _matrix[14] = 0;
    _matrix[15] = 1;
  }

  /// Returns the forward matrix components for the current factor.
  /// (m00, m01, m10, m11)
  (double, double, double, double) get matrixComponents {
    final f = _factor;
    final m00 = 1.0 + f * (IsometricComponent.cos30 - 1.0);
    final m01 = f * (-IsometricComponent.cos30);
    final m10 = f * IsometricComponent.sin30;
    final m11 = 1.0 + f * (IsometricComponent.sin30 - 1.0);
    return (m00, m01, m10, m11);
  }

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    if (_factor < 0.001) {
      draw(canvas);
      return;
    }
    canvas.save();
    canvas.transform(_matrix);
    draw(canvas);
    canvas.restore();
  }
}
