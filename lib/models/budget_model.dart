class BudgetModel {
  String id;
  String userId;
  String category;
  double amount;
  double spent;
  String period; // 'weekly' or 'monthly'
  DateTime startDate;
  DateTime endDate;

  BudgetModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.amount,
    this.spent = 0,
    required this.period,
    required this.startDate,
    required this.endDate,
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
    );
  }
}
