class BudgetModel {
  String id;
  String userId;
  String category;
  double amount;
  double spent;
  String period; // 'weekly' or 'monthly'
  DateTime startDate;
  DateTime endDate;
  String? linkedAlertRuleId; // Track which alert rule created this budget
  bool isAutoCreated; // Track if created automatically from alert

  BudgetModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.amount,
    this.spent = 0,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.linkedAlertRuleId,
    this.isAutoCreated = false,
  });

  double get remaining => amount - spent;
  double get percentSpent => spent / amount * 100;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'category': category,
      'amount': amount,
      'spent': spent,
      'period': period,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'linkedAlertRuleId': linkedAlertRuleId,
      'isAutoCreated': isAutoCreated,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      category: map['category'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      spent: (map['spent'] ?? 0).toDouble(),
      period: map['period'] ?? 'monthly',
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(map['endDate'] ?? DateTime.now().toIso8601String()),
      linkedAlertRuleId: map['linkedAlertRuleId'],
      isAutoCreated: map['isAutoCreated'] ?? false,
    );
  }

  BudgetModel copyWith({
    String? id,
    String? userId,
    String? category,
    double? amount,
    double? spent,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    String? linkedAlertRuleId,
    bool? isAutoCreated,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      spent: spent ?? this.spent,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      linkedAlertRuleId: linkedAlertRuleId ?? this.linkedAlertRuleId,
      isAutoCreated: isAutoCreated ?? this.isAutoCreated,
    );
  }
}
