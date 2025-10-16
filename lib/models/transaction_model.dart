import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String type; // 'income' or 'expense'
  final String category;
  final double amount;
  final String description;
  final DateTime date;
  final String? source;
  final String? paymentMethod;
  final List<String>? tags;
  final Map<String, dynamic>? metadata;

  // Savings allocation fields
  final double? savingsAllocation; // Amount allocated to savings from this transaction
  final String? savingsGoalId; // Reference to savings rule/goal
  final String? savingsGoalName; // Goal name for display

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
    this.savingsAllocation,
    this.savingsGoalId,
    this.savingsGoalName,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'category': category,
      'amount': amount,
      'description': description,
      'date': Timestamp.fromDate(date),
      'source': source,
      'paymentMethod': paymentMethod,
      'tags': tags,
      'metadata': metadata,
      'savingsAllocation': savingsAllocation,
      'savingsGoalId': savingsGoalId,
      'savingsGoalName': savingsGoalName,
    };
  }

  // Create from Firestore Map
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is Timestamp) return dateValue.toDate();
      if (dateValue is String) return DateTime.parse(dateValue);
      return DateTime.now();
    }
    return TransactionModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? 'expense',
      category: map['category'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      date: parseDate(map['date']),
      source: map['source'],
      paymentMethod: map['paymentMethod'],
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      metadata: map['metadata'],
      savingsAllocation: map['savingsAllocation']?.toDouble(),
      savingsGoalId: map['savingsGoalId'],
      savingsGoalName: map['savingsGoalName'],
    );
  }

  // CopyWith method for creating modified copies
  TransactionModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? category,
    double? amount,
    String? description,
    DateTime? date,
    String? source,
    String? paymentMethod,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    double? savingsAllocation,
    String? savingsGoalId,
    String? savingsGoalName,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      source: source ?? this.source,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      savingsAllocation: savingsAllocation ?? this.savingsAllocation,
      savingsGoalId: savingsGoalId ?? this.savingsGoalId,
      savingsGoalName: savingsGoalName ?? this.savingsGoalName,
    );
  }

  // Helper to get actual expense amount (total - savings allocation)
  double get actualExpenseAmount {
    if (type == 'expense' && savingsAllocation != null) {
      return amount - savingsAllocation!;
    }
    return amount;
  }

  // Helper to check if transaction has savings allocation
  bool get hasSavingsAllocation {
    return savingsAllocation != null && savingsAllocation! > 0;
  }
}