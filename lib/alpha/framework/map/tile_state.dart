/// 格子状态基类
///
/// 代表格子上的运行时状态效果（火焰、陷阱等）。
/// 状态是稀疏数据，只有少数格子包含状态。
abstract class TileState {
  const TileState();

  String get type;
  Map<String, dynamic> toJson();
}
