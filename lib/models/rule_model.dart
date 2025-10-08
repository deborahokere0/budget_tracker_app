class RuleModel {
  String id;
  String userId;
  String name;
  String type; // 'allocation', 'savings', 'alert', 'boost'
  Map<String, dynamic> conditions;
  Map<String, dynamic> actions;
  int priority; // 1-5, higher priority rules are applied first
  bool isActive;
  DateTime createdAt;
  DateTime? lastTriggered;

  RuleModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.conditions,
    required this.actions,
    this.priority = 1,
    this.isActive = true,
    required this.createdAt,
    this.lastTriggered,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type,
      'conditions': conditions,
      'actions': actions,
      'priority': priority,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastTriggered': lastTriggered?.toIso8601String(),
    };
  }

  factory RuleModel.fromMap(Map<String, dynamic> map) {
    return RuleModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'allocation',
      conditions: Map<String, dynamic>.from(map['conditions'] ?? {}),
      actions: Map<String, dynamic>.from(map['actions'] ?? {}),
      priority: map['priority'] ?? 1,
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastTriggered: map['lastTriggered'] != null
          ? DateTime.parse(map['lastTriggered'])
          : null,
    );
  }
}