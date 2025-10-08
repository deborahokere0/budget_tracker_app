class TransactionModel {
  String id;
  String userId;
  String type; // 'income' or 'expense'
  String category;
  double amount;
  String description;
  DateTime date;
  String? source; // For income - salary, gig, etc.

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
    this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'category': category,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'source': source,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      category: map['category'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      source: map['source'],
    );
  }
}
