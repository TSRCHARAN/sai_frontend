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
      // Append 'Z' to force UTC parsing if not present, then convert to Local
      createdAt: DateTime.parse(json['created_at'].toString().endsWith('Z') 
          ? json['created_at'] 
          : "${json['created_at']}Z").toLocal(),
      targetTime: json['target_time'] != null 
          ? DateTime.parse(json['target_time'].toString().endsWith('Z') 
              ? json['target_time'] 
              : "${json['target_time']}Z").toLocal() 
          : null,
      planStatus: json['plan_status'],
    );
  }
}
