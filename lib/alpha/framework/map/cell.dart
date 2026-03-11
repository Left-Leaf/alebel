/// 格子配置基类
///
/// 定义格子的静态属性（不可变配置）。
/// 子类通过继承定义具体的格子类型。
/// [id] 对应 [CellRegistry] 中的整数键，用于序列化。
abstract class Cell {
  const Cell();

  int get id;

  String get name;
}
