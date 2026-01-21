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

  // Income allocation tracking fields
  double? weeklyAllocatedAmount;
  DateTime? weekStartDate;

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
    this.weeklyAllocatedAmount,
    this.weekStartDate,
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
      'weeklyAllocatedAmount': weeklyAllocatedAmount,
      'weekStartDate': weekStartDate?.toIso8601String(),
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
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      lastTriggered: map['lastTriggered'] != null
          ? DateTime.parse(map['lastTriggered'])
          : null,
      targetAmount: map['targetAmount']?.toDouble(),
      currentAmount: map['currentAmount']?.toDouble(),
      goalName: map['goalName'],
      isPiggyBank: map['isPiggyBank'],
      weeklyAllocatedAmount: map['weeklyAllocatedAmount']?.toDouble(),
      weekStartDate: map['weekStartDate'] != null
          ? DateTime.parse(map['weekStartDate'])
          : null,
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
    double? weeklyAllocatedAmount,
    DateTime? weekStartDate,
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
      weeklyAllocatedAmount:
          weeklyAllocatedAmount ?? this.weeklyAllocatedAmount,
      weekStartDate: weekStartDate ?? this.weekStartDate,
    );
  }

  // Helper to get savings progress percentage
  double get savingsProgress {
    if (targetAmount == null || targetAmount == 0 || currentAmount == null) {
      return 0.0;
    }
    return (currentAmount! / targetAmount! * 100).clamp(0, 100);
  }

  // Getter for target category from actions map
  String? get targetCategory => actions['targetCategory'] as String?;

  /// Check if this rule applies to a given income source/category
  bool appliesToIncomeSource(String incomeCategory) {
    // Check if conditions specify income sources
    final incomeSources = conditions['incomeSources'];
    if (incomeSources == null) {
      // No specific sources means applies to all
      return true;
    }
    if (incomeSources is List) {
      return incomeSources.contains(incomeCategory) ||
          incomeSources.contains('all');
    }
    if (incomeSources is String) {
      return incomeSources == incomeCategory || incomeSources == 'all';
    }
    return true;
  }

  /// Calculate allocation amount based on rule conditions
  double calculateAllocation(double incomeAmount) {
    final allocationType = actions['allocationType'] as String? ?? 'percentage';
    final allocationValue =
        (actions['allocationValue'] as num?)?.toDouble() ?? 0;

    if (allocationType == 'percentage') {
      return incomeAmount * (allocationValue / 100);
    } else if (allocationType == 'fixed') {
      return allocationValue.clamp(0, incomeAmount);
    }
    return 0;
  }

  /// Check if weekly allocation needs to be reset (new week started)
  bool needsWeeklyReset() {
    if (weekStartDate == null) return true;

    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final normalizedCurrentWeekStart = DateTime(
      currentWeekStart.year,
      currentWeekStart.month,
      currentWeekStart.day,
    );
    final normalizedStoredWeekStart = DateTime(
      weekStartDate!.year,
      weekStartDate!.month,
      weekStartDate!.day,
    );

    return normalizedCurrentWeekStart.isAfter(normalizedStoredWeekStart);
  }
}
