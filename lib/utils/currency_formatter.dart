import 'package:intl/intl.dart';

class CurrencyFormatter {
  // Format with Nigerian Naira symbol and comma separators (e.g., ₦3,000,000.00)
  static String format(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '₦',
      decimalDigits: 2,
      locale: 'en_NG', // Nigerian locale for proper formatting
    );
    return formatter.format(amount);
  }

  // Format without decimals for whole numbers (e.g., ₦3,000,000)
  static String formatWhole(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '₦',
      decimalDigits: 0,
      locale: 'en_NG',
    );
    return formatter.format(amount);
  }

  // Compact format for large numbers (e.g., ₦3.5M, ₦125K)
  static String formatCompact(double amount) {
    if (amount >= 1000000) {
      return '₦${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₦${(amount / 1000).toStringAsFixed(0)}K';
    }
    return format(amount);
  }

  // Format without currency symbol, just comma separators (e.g., 3,000,000.00)
  static String formatWithoutSymbol(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
      locale: 'en_NG',
    );
    return formatter.format(amount).trim();
  }

  // Parse string to double, removing commas and currency symbols
  static double parse(String value) {
    // Remove currency symbol, commas, and spaces
    final cleanValue = value
        .replaceAll('₦', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();

    return double.tryParse(cleanValue) ?? 0.0;
  }
}