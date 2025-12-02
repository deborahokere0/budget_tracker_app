import 'package:flutter/material.dart';

/// Single source of truth for all transaction and rule categories
class CategoryConstants {
  // Expense categories
  static const List<String> expenseCategories = [
    'Food',
    'Transport',
    'Data',
    'Entertainment',
    'Utilities',
    'Healthcare',
    'Education',
    'Shopping',
    'Emergency',
    'Other',
  ];

  // Income categories
  static const List<String> incomeCategories = [
    'Freelance',
    'Salary',
    'Gig Work',
    'Investment',
    'Gift',
    'Other',
  ];

  // Category icons for UI
  static const Map<String, IconData> categoryIcons = {
    'Food': Icons.restaurant,
    'Transport': Icons.directions_car,
    'Data': Icons.wifi,
    'Entertainment': Icons.movie,
    'Utilities': Icons.electrical_services,
    'Healthcare': Icons.local_hospital,
    'Education': Icons.school,
    'Shopping': Icons.shopping_bag,
    'Emergency': Icons.emergency,
    'Other': Icons.more_horiz,
    'Salary': Icons.account_balance_wallet,
    'Freelance': Icons.work,
    'Gig Work': Icons.motorcycle,
    'Investment': Icons.trending_up,
    'Gift': Icons.card_giftcard,
  };

  // Category colors for UI (optional)
  static const Map<String, Color> categoryColors = {
    'Food': Color(0xFFFF6B6B),
    'Transport': Color(0xFF4ECDC4),
    'Data': Color(0xFF95E1D3),
    'Entertainment': Color(0xFFF38181),
    'Utilities': Color(0xFFAA96DA),
    'Healthcare': Color(0xFFFF8B94),
    'Education': Color(0xFF70A1D7),
    'Shopping': Color(0xFFFFAA64),
    'Emergency': Color(0xFFFF4757),
    'Other': Color(0xFF95A5A6),
    'Salary': Color(0xFF26DE81),
    'Freelance': Color(0xFF20BF6B),
    'Gig Work': Color(0xFF45B7D1),
    'Investment': Color(0xFF2ECC71),
    'Gift': Color(0xFFFEA47F),
  };

  // Get icon for category
  static IconData getIcon(String category) {
    return categoryIcons[category] ?? Icons.category;
  }

  // Get color for category
  static Color getColor(String category) {
    return categoryColors[category] ?? const Color(0xFF95A5A6);
  }

  // Validate if category exists in expense categories
  static bool isValidExpenseCategory(String category) {
    return expenseCategories.contains(category);
  }

  // Validate if category exists in income categories
  static bool isValidIncomeCategory(String category) {
    return incomeCategories.contains(category);
  }
}
