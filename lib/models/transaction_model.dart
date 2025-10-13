class TransactionModel {
  String id;
  String userId;
  String type; // 'income', 'expense', or 'savings'
  String category;
  double amount;
  String description;
  DateTime date;
  String? source; // For income - salary, gig, etc.
  String? paymentMethod;
  List<String>? tags;
  Map<String, dynamic>? metadata;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
    this.source,
    this.paymentMethod,
    this.tags,
    this.metadata,
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
      'paymentMethod': paymentMethod,
      'tags': tags,
      'metadata': metadata,
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
      paymentMethod: map['paymentMethod'],
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }
}