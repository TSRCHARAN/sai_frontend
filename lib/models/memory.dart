class Memory {
  final int id;
  final String content;
  final String type;
  final DateTime createdAt;
  final DateTime? targetTime;
  final String? planStatus;

  Memory({
    required this.id,
    required this.content,
    required this.type,
    required this.createdAt,
    this.targetTime,
    this.planStatus,
  });

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'],
      content: json['content'],
      type: json['memory_type'],
      createdAt: DateTime.parse(json['created_at']),
      targetTime: json['target_time'] != null ? DateTime.parse(json['target_time']) : null,
      planStatus: json['plan_status'],
    );
  }
}
