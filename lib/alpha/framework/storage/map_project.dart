/// 地图工程元数据
///
/// 对应 manifest.json 的内存表示，记录工程名称、版本、
/// 默认地形、时间戳以及所有区块坐标。
class MapProject {
  final String name;
  final int version;
  final int defaultCellId;
  final DateTime createdAt;
  DateTime modifiedAt;
  final List<({int x, int y})> chunks;

  MapProject({
    required this.name,
    this.version = 1,
    this.defaultCellId = 0,
    required this.createdAt,
    required this.modifiedAt,
    List<({int x, int y})>? chunks,
  }) : chunks = chunks ?? [];

  factory MapProject.fromJson(Map<String, dynamic> json) {
    final chunkList = (json['chunks'] as List<dynamic>).map((e) {
      final map = e as Map<String, dynamic>;
      return (x: map['x'] as int, y: map['y'] as int);
    }).toList();

    return MapProject(
      name: json['name'] as String,
      version: json['version'] as int? ?? 1,
      defaultCellId: json['defaultCellId'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      chunks: chunkList,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'defaultCellId': defaultCellId,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'chunks': chunks.map((c) => {'x': c.x, 'y': c.y}).toList(),
      };
}
