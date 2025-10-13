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

  // Savings-specific fields
  double? targetAmount;
  double? currentAmount;
  String? goalName;
  bool? isPiggyBank;

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
    this.targetAmount,
    this.currentAmount,
    this.goalName,
    this.isPiggyBank,
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
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'goalName': goalName,
      'isPiggyBank': isPiggyBank,
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
      targetAmount: map['targetAmount']?.toDouble(),
      currentAmount: map['currentAmount']?.toDouble(),
      goalName: map['goalName'],
      isPiggyBank: map['isPiggyBank'],
    );
  }

  RuleModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    Map<String, dynamic>? conditions,
    Map<String, dynamic>? actions,
    int? priority,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastTriggered,
    double? targetAmount,
    double? currentAmount,
    String? goalName,
    bool? isPiggyBank,
  }) {
    return RuleModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      goalName: goalName ?? this.goalName,
      isPiggyBank: isPiggyBank ?? this.isPiggyBank,
    );
  }

  // Helper to get savings progress percentage
  double get savingsProgress {
    if (targetAmount == null || targetAmount == 0 || currentAmount == null) {
      return 0.0;
    }
    return (currentAmount! / targetAmount! * 100).clamp(0, 100);
  }
}