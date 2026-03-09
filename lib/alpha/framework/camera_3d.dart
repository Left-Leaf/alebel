import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

/// 真实 3D 正交相机模型 — 模仿 Flame [Transform2D] 的可变属性 + 惰性矩阵模式。
///
/// 游戏世界在 z=0 地平面上，相机从空中俯视。
/// 4 个参数完整描述相机状态：
///
/// - [target]：相机注视的地面点（世界坐标）
/// - [yaw]：绕垂直轴旋转（弧度），0 = 正北
/// - [pitch]：俯仰角（弧度），0 = 水平，π/2 = 正上方俯视
/// - [zoom]：缩放倍率
///
/// 属性修改后矩阵延迟重算（仅在读取 [transformMatrix] 时触发），
/// 多次连续修改只重算一次。实现 [ChangeNotifier] 以通知属性变化。
///
/// 投影推导（正交投影，地面 z=0）：
/// ```
/// dx = wx - target.x,  dy = wy - target.y
///
/// // 1. yaw 旋转
/// rx =  cos(yaw)*dx + sin(yaw)*dy
/// ry = -sin(yaw)*dx + cos(yaw)*dy
///
/// // 2. pitch 压缩
/// screen_x = rx
/// screen_y = sin(pitch) * ry
///
/// // 3. zoom 缩放
/// sx = zoom * screen_x
/// sy = zoom * screen_y
/// ```
class Camera3D extends ChangeNotifier {
  final Vector2 _target;
  double _yaw;
  double _pitch;
  double _zoom;

  bool _recalculate = true;
  final Float64List _transformMatrix = Float64List(16);

  /// 等角投影的 pitch 值：arcsin(1/√3) ≈ 35.264°。
  static final double isometricPitch = math.asin(1 / math.sqrt(3));

  /// 等角投影的基础 zoom 值：√(3/2) ≈ 1.2247。
  static final double isometricBaseZoom = math.sqrt(3 / 2);

  // ---------------------------------------------------------------------------
  // 构造
  // ---------------------------------------------------------------------------

  Camera3D({
    Vector2? target,
    double yaw = 0,
    double pitch = math.pi / 2,
    double zoom = 1,
  })  : _target = target?.clone() ?? Vector2.zero(),
        _yaw = yaw,
        _pitch = pitch,
        _zoom = zoom;

  /// 正上方俯视（pitch = π/2，yaw = 0）。
  factory Camera3D.topDown({Vector2? target, double zoom = 1}) =>
      Camera3D(target: target, zoom: zoom);

  /// 标准等角投影（yaw = -π/4，pitch ≈ 35.264°，zoom = √(3/2) * userZoom）。
  factory Camera3D.isometric({Vector2? target, double zoom = 1}) => Camera3D(
        target: target,
        yaw: -math.pi / 4,
        pitch: isometricPitch,
        zoom: isometricBaseZoom * zoom,
      );

  /// 复制另一个 Camera3D 的所有属性。
  factory Camera3D.copy(Camera3D other) => Camera3D(
        target: other._target,
        yaw: other._yaw,
        pitch: other._pitch,
        zoom: other._zoom,
      );

  /// 克隆自身。
  Camera3D clone() => Camera3D.copy(this);

  // ---------------------------------------------------------------------------
  // 属性
  // ---------------------------------------------------------------------------

  /// 相机注视的地面点（世界坐标）。
  ///
  /// 返回内部可变引用。直接修改 [Vector2] 字段（如 `target.x = 5`）
  /// **不会**触发通知；请改用 [target] setter 或 [targetX] / [targetY]。
  Vector2 get target => _target;
  set target(Vector2 v) {
    _target.setFrom(v);
    _markAsModified();
  }

  double get targetX => _target.x;
  set targetX(double v) {
    _target.x = v;
    _markAsModified();
  }

  double get targetY => _target.y;
  set targetY(double v) {
    _target.y = v;
    _markAsModified();
  }

  /// 绕垂直轴旋转（弧度），0 = 正北。
  double get yaw => _yaw;
  set yaw(double v) {
    _yaw = v;
    _markAsModified();
  }

  /// 俯仰角（弧度），0 = 水平，π/2 = 正上方俯视。
  double get pitch => _pitch;
  set pitch(double v) {
    _pitch = v;
    _markAsModified();
  }

  /// 缩放倍率。
  double get zoom => _zoom;
  set zoom(double v) {
    _zoom = v;
    _markAsModified();
  }

  // ---------------------------------------------------------------------------
  // 预设
  // ---------------------------------------------------------------------------

  /// 设为正上方俯视（pitch = π/2，yaw = 0），可选更新 target 和 zoom。
  void setToTopDown({Vector2? target, double? zoom}) {
    _yaw = 0;
    _pitch = math.pi / 2;
    if (zoom != null) _zoom = zoom;
    if (target != null) _target.setFrom(target);
    _markAsModified();
  }

  /// 设为标准等角投影（yaw = -π/4，pitch ≈ 35.264°），可选更新 target 和 zoom。
  void setToIsometric({Vector2? target, double? zoom}) {
    _yaw = -math.pi / 4;
    _pitch = isometricPitch;
    _zoom = isometricBaseZoom * (zoom ?? 1);
    if (target != null) _target.setFrom(target);
    _markAsModified();
  }

  // ---------------------------------------------------------------------------
  // 变换矩阵（惰性重算）
  // ---------------------------------------------------------------------------

  /// 列主序 4x4 投影矩阵。
  ///
  /// 按需惰性重算并缓存，返回的引用不可外部修改。
  ///
  /// 矩阵布局：
  /// ```
  ///   m00 =  zoom * cos(yaw)
  ///   m10 = -zoom * sin(pitch) * sin(yaw)
  ///   m01 =  zoom * sin(yaw)
  ///   m11 =  zoom * sin(pitch) * cos(yaw)
  ///   tx  = -(m00 * target.x + m01 * target.y)
  ///   ty  = -(m10 * target.x + m11 * target.y)
  /// ```
  Float64List get transformMatrix {
    if (_recalculate) {
      _recomputeMatrix();
      _recalculate = false;
    }
    return _transformMatrix;
  }

  // ---------------------------------------------------------------------------
  // 坐标转换
  // ---------------------------------------------------------------------------

  /// 世界坐标 → 屏幕坐标。
  Vector2 worldToScreen(Vector2 point, {Vector2? output}) {
    final m = transformMatrix;
    final x = m[0] * point.x + m[4] * point.y + m[12];
    final y = m[1] * point.x + m[5] * point.y + m[13];
    return (output?..setValues(x, y)) ?? Vector2(x, y);
  }

  /// 屏幕坐标 → 世界坐标。
  ///
  /// 若当前变换退化（行列式为 0），返回零向量。
  Vector2 screenToWorld(Vector2 point, {Vector2? output}) {
    final m = transformMatrix;
    var det = m[0] * m[5] - m[1] * m[4];
    if (det != 0) {
      det = 1 / det;
    }
    final x = ((point.x - m[12]) * m[5] - (point.y - m[13]) * m[4]) * det;
    final y = ((point.y - m[13]) * m[0] - (point.x - m[12]) * m[1]) * det;
    return (output?..setValues(x, y)) ?? Vector2(x, y);
  }

  /// 屏幕空间方向 → 世界空间方向（仅旋转，不含 zoom / 平移）。
  ///
  /// 对投影矩阵的 2x2 旋转部分求逆：
  /// ```
  /// M = [cos(yaw),             sin(yaw)          ]
  ///     [-sin(pitch)*sin(yaw),  sin(pitch)*cos(yaw)]
  ///
  /// M⁻¹ = (1/sinPitch) * [ sinPitch*cos(yaw), -sin(yaw)         ]
  ///                       [ sinPitch*sin(yaw),  cos(yaw)          ]
  /// ```
  Vector2 screenToWorldDirection(double sx, double sy) {
    final cosYaw = math.cos(_yaw);
    final sinYaw = math.sin(_yaw);
    final sinPitch = math.sin(_pitch);

    if (sinPitch.abs() < 1e-10) return Vector2(sx, sy);

    final invSP = 1.0 / sinPitch;
    return Vector2(
      cosYaw * sx - sinYaw * invSP * sy,
      sinYaw * sx + cosYaw * invSP * sy,
    );
  }

  // ---------------------------------------------------------------------------
  // 批量设置
  // ---------------------------------------------------------------------------

  /// 从另一个 Camera3D 复制所有属性（单次通知）。
  void setFrom(Camera3D other) {
    _target.setFrom(other._target);
    _yaw = other._yaw;
    _pitch = other._pitch;
    _zoom = other._zoom;
    _markAsModified();
  }

  /// 从 4x4 矩阵逆向推导并设置相机参数（单次通知）。
  ///
  /// 推导公式：
  /// ```
  ///   zoom  = √(m00² + m01²)
  ///   yaw   = atan2(m01, m00)
  ///   pitch = arcsin(√(m10² + m11²) / zoom)
  ///   target = -M⁻¹ · [tx, ty]ᵀ
  /// ```
  void setFromMatrix(Float64List matrix) {
    final m00 = matrix[0];
    final m10 = matrix[1];
    final m01 = matrix[4];
    final m11 = matrix[5];
    final tx = matrix[12];
    final ty = matrix[13];

    _zoom = math.sqrt(m00 * m00 + m01 * m01);
    _yaw = math.atan2(m01, m00);

    final row1Len = math.sqrt(m10 * m10 + m11 * m11);
    _pitch = _zoom > 1e-10
        ? math.asin((row1Len / _zoom).clamp(0.0, 1.0))
        : 0.0;

    final det = m00 * m11 - m01 * m10;
    if (det.abs() < 1e-10) {
      _target.setValues(0, 0);
    } else {
      final invDet = 1.0 / det;
      _target.setValues(
        -invDet * (m11 * tx - m01 * ty),
        -invDet * (-m10 * tx + m00 * ty),
      );
    }
    _markAsModified();
  }

  /// 将 this 设为 [a] 和 [b] 的逐分量线性插值（零分配，单次通知）。
  void lerpFrom(Camera3D a, Camera3D b, double t) {
    _target.setValues(
      a._target.x + (b._target.x - a._target.x) * t,
      a._target.y + (b._target.y - a._target.y) * t,
    );
    _yaw = a._yaw + (b._yaw - a._yaw) * t;
    _pitch = a._pitch + (b._pitch - a._pitch) * t;
    _zoom = a._zoom + (b._zoom - a._zoom) * t;
    _markAsModified();
  }

  // ---------------------------------------------------------------------------
  // 判等 / 格式化
  // ---------------------------------------------------------------------------

  /// 检查是否与 [other] 近似相等（绝对容差）。
  bool closeTo(Camera3D other, {double tolerance = 1e-10}) {
    return (_target.x - other._target.x).abs() <= tolerance &&
        (_target.y - other._target.y).abs() <= tolerance &&
        (_yaw - other._yaw).abs() <= tolerance &&
        (_pitch - other._pitch).abs() <= tolerance &&
        (_zoom - other._zoom).abs() <= tolerance;
  }

  @override
  String toString() =>
      'Camera3D(target: $_target, yaw: ${(_yaw * 180 / math.pi).toStringAsFixed(1)}°, '
      'pitch: ${(_pitch * 180 / math.pi).toStringAsFixed(1)}°, zoom: ${_zoom.toStringAsFixed(3)})';

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  void _markAsModified() {
    _recalculate = true;
    notifyListeners();
  }

  void _recomputeMatrix() {
    final cosYaw = math.cos(_yaw);
    final sinYaw = math.sin(_yaw);
    final sinPitch = math.sin(_pitch);

    final m00 = _zoom * cosYaw;
    final m10 = -_zoom * sinPitch * sinYaw;
    final m01 = _zoom * sinYaw;
    final m11 = _zoom * sinPitch * cosYaw;

    final m = _transformMatrix;
    m[0] = m00;
    m[1] = m10;
    m[2] = 0;
    m[3] = 0;
    m[4] = m01;
    m[5] = m11;
    m[6] = 0;
    m[7] = 0;
    m[8] = 0;
    m[9] = 0;
    m[10] = 1;
    m[11] = 0;
    m[12] = -(m00 * _target.x + m01 * _target.y);
    m[13] = -(m10 * _target.x + m11 * _target.y);
    m[14] = 0;
    m[15] = 1;
  }
}
