class FinancialCalculator {
  /// Calculate safe-to-spend amount (30% of net amount)
  static double calculateSafeToSpend(double netAmount) {
    return netAmount > 0 ? netAmount * 0.3 : 0.0;
  }

  /// Calculate days until next payday (assumes 2nd of next month)
  static int calculateDaysUntilPayday() {
    final now = DateTime.now();
    // Payday assumed to be the 2nd of the next month
    final nextPayday = DateTime(now.year, now.month + 1, 2);
    final difference = nextPayday.difference(now).inDays;
    // If today is the 2nd, the difference might be 0 or depending on time,
    // but the logic in original code was just next month's 2nd.
    return difference;
  }

  /// Calculate runway days based on available cash and weekly burn rate
  static int calculateRunwayDays(double netAmount, double weeklyExpenses) {
    final dailyBurn = weeklyExpenses / 7;
    if (dailyBurn <= 0) return 0;
    return (netAmount / dailyBurn).floor();
  }

  /// Determine runway status based on days
  static String getRunwayStatus(int days) {
    return days > 14 ? 'STABLE' : 'CRITICAL';
  }

  /// Calculate income volatility percentage
  /// Returns percentage change (positive or negative)
  static int calculateVolatility(double currentIncome, double previousIncome) {
    if (previousIncome <= 0) return 0;
    return ((currentIncome - previousIncome) / previousIncome * 100).round();
  }
}
