import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/budget_model.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../transactions/add_transaction_screen.dart';
import '../widgets/enhanced_alert_banner.dart';

class VariableEarnerDashboard extends StatelessWidget {
  final UserModel user;
  final Map<String, dynamic> stats;
  final VoidCallback onRefresh;
  final FirebaseService _firebaseService = FirebaseService();

  VariableEarnerDashboard({
    super.key,
    required this.user,
    required this.onRefresh,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: StreamBuilder<Map<String, dynamic>>(
          // Stream stats instead of using static prop
          stream: _getStatsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final stats =
                snapshot.data ??
                {
                  'netAmount': 0.0,
                  'weeklyIncome': 0.0,
                  'weeklyExpenses': 0.0,
                  'totalIncome': 0.0,
                  'totalExpenses': 0.0,
                };

            final netAmount = stats['netAmount'] ?? 0.0;
            final weeklyIncome = stats['weeklyIncome'] ?? 0.0;
            final weeklyExpenses = stats['weeklyExpenses'] ?? 0.0;

            // Calculate runway period (how many days current funds will last)
            final dailyBurn = weeklyExpenses / 7;
            final runwayDays = dailyBurn > 0
                ? (netAmount / dailyBurn).round()
                : 0;
            final runwayStatus = runwayDays > 14 ? 'STABLE' : 'CRITICAL';

            // Income volatility check
            final lastWeekIncome =
                150000.0; // This would come from historical data
            final incomeChange =
                ((weeklyIncome - lastWeekIncome) / lastWeekIncome * 100)
                    .round();
            final isIncomeVolatile = incomeChange.abs() > 25;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Home',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Net Amount',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Oct 13 - Oct 19',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                CurrencyFormatter.format(netAmount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Earned',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(weeklyIncome),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Spent',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(
                                          weeklyExpenses,
                                        ),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'RUNWAY PERIOD',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.warning,
                                            color: runwayStatus == 'STABLE'
                                                ? Colors.yellow
                                                : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            runwayStatus,
                                            style: TextStyle(
                                              color: runwayStatus == 'STABLE'
                                                  ? Colors.yellow
                                                  : Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Alert Banners
                  EnhancedAlertBannersContainer(userId: user.uid),

                  // White content area
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Weekly Budgets
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Weekly Budgets',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text('See All >'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          StreamBuilder<List<BudgetModel>>(
                            stream: _firebaseService.getBudgets(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final budgets = snapshot.data!.take(3).toList();

                              return Row(
                                children: budgets
                                    .map(
                                      (budget) => Expanded(
                                        child: _buildWeeklyBudgetCard(budget),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // Income Volatility Alert
                          if (isIncomeVolatile)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.green),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.trending_up,
                                    color: AppTheme.green,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Income Volatility Alert',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.green,
                                          ),
                                        ),
                                        Text(
                                          'You earned ${incomeChange.abs()}% ${incomeChange > 0 ? 'more' : 'less'} than last week. Congratulations!',
                                          style: TextStyle(
                                            color: AppTheme.green,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Emergency Fund Transfer
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Emergency Fund Transfer',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  CurrencyFormatter.format(475000),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₦10,000 transferred this month',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppTheme.primaryBlue,
                                    minimumSize: const Size(
                                      double.infinity,
                                      40,
                                    ),
                                  ),
                                  child: const Text('View Fund History'),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Top Income & Spend
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Top Income',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Fiverr'),
                                          Icon(Icons.calendar_today, size: 16),
                                        ],
                                      ),
                                      Text(
                                        CurrencyFormatter.format(45000),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.green,
                                        ),
                                      ),
                                      Text(
                                        '25 June',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Top Spend',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('KFC'),
                                          Icon(Icons.calendar_today, size: 16),
                                        ],
                                      ),
                                      Text(
                                        '-${CurrencyFormatter.format(9000)}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.red,
                                        ),
                                      ),
                                      Text(
                                        '24 June',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Action Buttons
                          _buildActionButtons(context),
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

  // Create stream that listens to transactions and recalculates stats
  Stream<Map<String, dynamic>> _getStatsStream() {
    return _firebaseService.getTransactions().asyncMap((transactions) async {
      // Recalculate stats from transactions
      double totalIncome = 0;
      double totalExpenses = 0;
      double weeklyIncome = 0;
      double weeklyExpenses = 0;
      double salaryIncome = 0;
      double gigIncome = 0;
      double totalSavings = 0;

      DateTime now = DateTime.now();
      DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));

      for (var transaction in transactions) {
        if (transaction.type == 'income') {
          totalIncome += transaction.amount;

          if (transaction.source?.toLowerCase() == 'salary' ||
              transaction.category.toLowerCase() == 'salary') {
            salaryIncome += transaction.amount;
          } else {
            gigIncome += transaction.amount;
          }

          if (transaction.date.isAfter(weekStart)) {
            weeklyIncome += transaction.amount;
          }
        } else if (transaction.type == 'expense') {
          totalExpenses += transaction.actualExpenseAmount;

          if (transaction.hasSavingsAllocation) {
            totalSavings += transaction.savingsAllocation!;
          }

          if (transaction.date.isAfter(weekStart)) {
            weeklyExpenses += transaction.actualExpenseAmount;
          }
        }
      }

      return {
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'totalSavings': totalSavings,
        'netAmount': totalIncome - totalExpenses,
        'weeklyIncome': weeklyIncome,
        'weeklyExpenses': weeklyExpenses,
        'salaryIncome': salaryIncome,
        'gigIncome': gigIncome,
      };
    });
  }

  Widget _buildWeeklyBudgetCard(BudgetModel budget) {
    final isOverBudget = budget.spent > budget.amount;
    final icon = _getCategoryIcon(budget.category);

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverBudget ? AppTheme.red : Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey..withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                budget.category,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(budget.amount),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(budget.spent),
            style: TextStyle(
              fontSize: 14,
              color: isOverBudget ? AppTheme.red : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
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
      default:
        return '📦';
    }
  }
}
