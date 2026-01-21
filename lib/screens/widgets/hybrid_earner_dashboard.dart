import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/budget_model.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/financial_calculator.dart';
import '../transactions/add_transaction_screen.dart';
// import '../widgets/enhanced_alert_banner.dart';
import 'budget_tracker_screen.dart';
import 'monthly_reset_manager.dart';

class HybridEarnerDashboard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRefresh;
  final FirebaseService _firebaseService = FirebaseService();

  HybridEarnerDashboard({
    super.key,
    required this.user,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _getStatsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final stats =
                snapshot.data ??
                {
                  'totalBalance': 0.0,
                  'salaryIncome': 0.0,
                  'gigIncome': 0.0,
                  'totalSavings': 0.0,
                  'weeklyIncome': 0.0,
                  'weeklyExpenses': 0.0,
                };

            final totalBalance = stats['totalBalance'] ?? 0.0;
            final salaryIncome = stats['salaryIncome'] ?? 0.0;
            final gigIncome = stats['gigIncome'] ?? 0.0;
            final totalSavings = stats['totalSavings'] ?? 0.0;
            final weeklyExpenses = stats['weeklyExpenses'] ?? 0.0;
            final weeklyIncome = stats['weeklyIncome'] ?? 0.0;

            // --- CALCULATIONS (Using Shared Utility) ---

            // Fixed Side: Safe-to-Spend (Monthly View)
            // Using Salary portion for stability calculation
            final monthlySafeToSpend = FinancialCalculator.calculateSafeToSpend(
              salaryIncome,
            );
            final daysUntilPayday =
                FinancialCalculator.calculateDaysUntilPayday();

            // Variable Side: Runway (Weekly View)
            // Using Total Balance vs Weekly Burn
            final runwayDays = FinancialCalculator.calculateRunwayDays(
              totalBalance,
              weeklyExpenses,
            );
            final runwayStatus = FinancialCalculator.getRunwayStatus(
              runwayDays,
            );

            // Volatility
            final lastWeekIncome = 150000.0; // Placeholder for historical data
            final volatility = FinancialCalculator.calculateVolatility(
              weeklyIncome,
              lastWeekIncome,
            );

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  MonthlyResetManager(
                    userId: user.uid,
                    onAlertsEnabled: onRefresh,
                  ),
                  // --- HEADER: TOTAL BALANCE MIX ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryBlue, AppTheme.darkBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hybrid Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B5BA6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Balance',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      CurrencyFormatter.format(totalBalance),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Pie Chart
                              Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white24,
                                ),
                                child: Center(
                                  child: CustomPaint(
                                    size: const Size(40, 40),
                                    painter: PieChartPainter(
                                      salaryIncome,
                                      gigIncome,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- DUAL SYSTEM CONTENT ---
                  Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. MONTHLY STABILITY (FIXED)
                          const Text(
                            'MONTHLY STABILITY (Salary)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  'Safe-to-Spend',
                                  CurrencyFormatter.format(monthlySafeToSpend),
                                  Icons.shield_outlined,
                                  AppTheme.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoCard(
                                  'Next Payday',
                                  '$daysUntilPayday Days',
                                  Icons.calendar_today,
                                  AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // 2. WEEKLY FLUX (VARIABLE)
                          const Text(
                            'WEEKLY FLUX (Gigs)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  'Runway',
                                  '$runwayDays Days',
                                  Icons.timelapse,
                                  runwayDays > 14
                                      ? AppTheme.green
                                      : AppTheme.orange,
                                  subtitle: runwayStatus,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoCard(
                                  'Volatility',
                                  '${volatility > 0 ? '+' : ''}$volatility%',
                                  Icons.trending_up,
                                  volatility.abs() > 25
                                      ? AppTheme.red
                                      : AppTheme.primaryBlue,
                                  subtitle: 'vs Last Week',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // 3. BUDGETS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Budgets',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const BudgetTrackerScreen(),
                                    ),
                                  );
                                },
                                child: const Text('See All >'),
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildBudgetCard(
                                  'Salary (Fixed)',
                                  const Color(0xFFE3F2FD), // Light Blue
                                  'monthly',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildBudgetCard(
                                  'Gigs (Flex)',
                                  const Color(0xFFF3E5F5), // Light Purple
                                  'weekly',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // TOTAL SAVINGS
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2B5BA6), Color(0xFF1E3A6D)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Savings',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        CurrencyFormatter.format(totalSavings),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.savings,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          _buildActionButtons(context, onRefresh),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.black54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Stream<Map<String, dynamic>> _getStatsStream() {
    return _firebaseService.getTransactions().asyncMap((transactions) async {
      double totalIncome = 0;
      double totalExpenses = 0;
      double salaryIncome = 0;
      double gigIncome = 0;
      double totalSavings = 0;
      double weeklyIncome = 0;
      double weeklyExpenses = 0;

      final now = DateTime.now();
      // Calculate start of current week (Monday)
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDay = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );

      for (var transaction in transactions) {
        final date = transaction.date;
        final isThisWeek =
            date.isAfter(weekStartDay) || date.isAtSameMomentAs(weekStartDay);

        if (transaction.type == 'income') {
          totalIncome += transaction.amount;
          if (isThisWeek) weeklyIncome += transaction.amount;

          if (transaction.source?.toLowerCase() == 'salary' ||
              transaction.category.toLowerCase() == 'salary') {
            salaryIncome += transaction.amount;
          } else {
            gigIncome += transaction.amount;
          }
        } else if (transaction.type == 'expense') {
          totalExpenses += transaction.actualExpenseAmount;
          if (isThisWeek) weeklyExpenses += transaction.actualExpenseAmount;

          if (transaction.hasSavingsAllocation) {
            totalSavings += transaction.savingsAllocation!;
          }
        }
      }

      return {
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'totalBalance': totalIncome - totalExpenses,
        'salaryIncome': salaryIncome,
        'gigIncome': gigIncome,
        'totalSavings': totalSavings,
        'weeklyIncome': weeklyIncome,
        'weeklyExpenses': weeklyExpenses,
      };
    });
  }

  Widget _buildBudgetCard(String title, Color bgColor, String period) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 12),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<BudgetModel>>(
            stream: _firebaseService.getBudgets(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text(
                  'No budgets',
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                );
              }

              final budgets = snapshot.data!
                  .where((b) => b.period == period)
                  .take(3) // Limit to 3 items per card
                  .toList();

              if (budgets.isEmpty) {
                return const Text(
                  'No budgets',
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                );
              }

              return Column(
                children: budgets.map((budget) {
                  final isOverBudget = budget.spent > budget.amount;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Text(
                          _getCategoryIcon(budget.category),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                budget.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${CurrencyFormatter.format(budget.spent)}/${CurrencyFormatter.format(budget.amount)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isOverBudget
                                      ? AppTheme.red
                                      : Colors.black54,
                                ),
                              ),
                              // Tiny progress bar
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (budget.spent / budget.amount).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.5,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isOverBudget
                                        ? AppTheme.red
                                        : AppTheme.green,
                                  ),
                                  minHeight: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return '🍔';
      case 'transport':
        return '🚗';
      case 'data':
        return '💾';
      case 'entertainment':
        return '🎬';
      case 'utilities':
        return '💡';
      case 'rent':
        return '🏠';
      case 'shopping':
        return '🛍️';
      case 'health':
        return '🏥';
      default:
        return '📦';
    }
  }
}

Widget _buildActionButtons(BuildContext context, VoidCallback onRefresh) {
  return Row(
    children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionScreen(
                  onTransactionAdded: onRefresh,
                  initialTransactionType: 'income',
                ),
              ),
            );
          },
          icon: const Icon(Icons.arrow_downward),
          label: const Text('Add Income'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionScreen(
                  onTransactionAdded: onRefresh,
                  initialTransactionType: 'expense',
                ),
              ),
            );
          },
          icon: const Icon(Icons.arrow_upward),
          label: const Text('Add Expense'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    ],
  );
}

// Custom Pie Chart Painter
class PieChartPainter extends CustomPainter {
  final double salary;
  final double gigs;

  PieChartPainter(this.salary, this.gigs);

  @override
  void paint(Canvas canvas, Size size) {
    final total = salary + gigs;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Salary portion (blue)
    final salaryPaint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..style = PaintingStyle.fill;

    final salaryAngle = (salary / total) * 360 * (3.14159 / 180);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * (3.14159 / 180),
      salaryAngle,
      true,
      salaryPaint,
    );

    // Gigs portion (purple)
    final gigsPaint = Paint()
      ..color = const Color(0xFFB794F4)
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * (3.14159 / 180) + salaryAngle,
      (gigs / total) * 360 * (3.14159 / 180),
      true,
      gigsPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
