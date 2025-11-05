class DataValidator {
  /// Safely parse a double value with fallback
  static double safeParseDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Safely parse an integer value with fallback
  static int safeParseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Safely parse a string value with fallback
  static String safeParseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  /// Safely parse a boolean value with fallback
  static bool safeParseBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is String) {
      final lowerValue = value.toLowerCase();
      if (lowerValue == 'true' || lowerValue == '1') return true;
      if (lowerValue == 'false' || lowerValue == '0') return false;
    }
    if (value is num) return value != 0;
    return fallback;
  }

  /// Validate and clamp a numeric value within range
  static double clampValue(double value, {double min = 0, double max = double.infinity}) {
    return value.clamp(min, max).toDouble();
  }

  /// Check if a string is a valid email
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Check if a string is a valid Nigerian phone number
  static bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^(\+234|0)[789][01]\d{8}$');
    return phoneRegex.hasMatch(phone.replaceAll(' ', ''));
  }

  /// Validate currency amount (non-negative)
  static double validateAmount(dynamic amount) {
    final parsed = safeParseDouble(amount);
    return parsed >= 0 ? parsed : 0.0;
  }

  /// Clean and format category names
  static String formatCategory(String category) {
    if (category.isEmpty) return 'Uncategorized';
    return category
        .split(' ')
        .map((word) => word.isNotEmpty
        ? word[0].toUpperCase() + word.substring(1).toLowerCase()
        : '')
        .join(' ')
        .trim();
  }

  /// Validate date range
  static bool isValidDateRange(DateTime start, DateTime end) {
    return start.isBefore(end) || start.isAtSameMomentAs(end);
  }

  /// Parse Firebase timestamp safely
  static DateTime parseFirebaseTimestamp(dynamic timestamp, {DateTime? fallback}) {
    fallback ??= DateTime.now();

    if (timestamp == null) return fallback;

    // Handle Firestore Timestamp
    if (timestamp.runtimeType.toString().contains('Timestamp')) {
      try {
        return timestamp.toDate();
      } catch (e) {
        return fallback;
      }
    }

    // Handle string dates
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? fallback;
    }

    // Handle milliseconds since epoch
    if (timestamp is num) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
      } catch (e) {
        return fallback;
      }
    }

    return fallback;
  }
}