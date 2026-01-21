class RuleModel {
  String id;
  String userId;
  String name;
  String type; // 'allocation', 'savings', 'alert', 'boost', 'income_allocation'
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

  // Income allocation specific fields (for variable earners)
  String? incomeSource; // 'all', 'Gig Work', 'Gift', etc.
  String? allocationType; // 'percentage' or 'fixed'
  double? allocationValue; // percentage or fixed amount
  String? targetCategory; // budget category to allocate to
  double? weeklyAllocatedAmount; // track current week allocations
  DateTime? weekStartDate; // track week for reset

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
    this.incomeSource,
    this.allocationType,
    this.allocationValue,
    this.targetCategory,
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
      'incomeSource': incomeSource,
      'allocationType': allocationType,
      'allocationValue': allocationValue,
      'targetCategory': targetCategory,
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
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastTriggered: map['lastTriggered'] != null
          ? DateTime.parse(map['lastTriggered'])
          : null,
      targetAmount: map['targetAmount']?.toDouble(),
      currentAmount: map['currentAmount']?.toDouble(),
      goalName: map['goalName'],
      isPiggyBank: map['isPiggyBank'],
      incomeSource: map['incomeSource'],
      allocationType: map['allocationType'],
      allocationValue: map['allocationValue']?.toDouble(),
      targetCategory: map['targetCategory'],
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
    String? incomeSource,
    String? allocationType,
    double? allocationValue,
    String? targetCategory,
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
      incomeSource: incomeSource ?? this.incomeSource,
      allocationType: allocationType ?? this.allocationType,
      allocationValue: allocationValue ?? this.allocationValue,
      targetCategory: targetCategory ?? this.targetCategory,
      weeklyAllocatedAmount: weeklyAllocatedAmount ?? this.weeklyAllocatedAmount,
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

  // Helper to check if rule applies to income source
  bool appliesToIncomeSource(String source) {
    if (type != 'income_allocation') return false;
    return incomeSource == 'all' || incomeSource == source;
  }

  // Helper to calculate allocation amount for given income
  double calculateAllocation(double incomeAmount) {
    if (allocationType == 'percentage' && allocationValue != null) {
      return incomeAmount * (allocationValue! / 100);
    } else if (allocationType == 'fixed' && allocationValue != null) {
      // Don't allocate more than the income amount
      return allocationValue! > incomeAmount ? incomeAmount : allocationValue!;
    }
    return 0.0;
  }

  // Check if this is start of new week for reset
  bool needsWeeklyReset() {
    if (weekStartDate == null) return true;
    
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final lastWeekStart = _getWeekStart(weekStartDate!);
    
    return weekStart.isAfter(lastWeekStart);
  }

  DateTime _getWeekStart(DateTime date) {
    // Get Monday of the week
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }
}