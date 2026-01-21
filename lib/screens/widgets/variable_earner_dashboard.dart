import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/budget_model.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../transactions/add_transaction_screen.dart';
import 'budget_tracker_screen.dart';
import 'monthly_reset_manager.dart';

import '../../utils/financial_calculator.dart'; // Add import

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

            // Calculate runway period using utility
            final runwayDays = FinancialCalculator.calculateRunwayDays(
              netAmount,
              weeklyExpenses,
            );
            final runwayStatus = FinancialCalculator.getRunwayStatus(
              runwayDays,
            );

            // Income volatility check
            final lastWeekIncome = 150000.0; // Would come from historical data
            final incomeChange = FinancialCalculator.calculateVolatility(
              weeklyIncome,
              lastWeekIncome,
            );
            final isIncomeVolatile = incomeChange.abs() > 25;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonthlyResetManager(
                    userId: user.uid,
                    onAlertsEnabled: onRefresh,
                  ),
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
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
                            color: Colors.white.withValues(
                              alpha: 0.1,
                            ), // Updated to withValues
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Net Amount',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _getDateRange(),
                                    style: const TextStyle(
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
                                      const Text(
                                        'Earned',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(weeklyIncome),
                                        style: const TextStyle(
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
                                      const Text(
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
                                        style: const TextStyle(
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
                                      const Text(
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
                        const SizedBox(height: 16),
                        // Income volatility indicator
                        if (isIncomeVolatile)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.orange),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  incomeChange > 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: AppTheme.orange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Income Volatility Alert',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Income ${incomeChange > 0 ? "increased" : "decreased"} by ${incomeChange.abs()}% from last week',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

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
                          // Weekly Budget Overview
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Weekly Budget Overview',
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
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 100,
                            child: StreamBuilder<List<BudgetModel>>(
                              stream: _firebaseService.getBudgets(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return const Center(
                                    child: Text('No budgets set'),
                                  );
                                }
                                final budgets = snapshot.data!
                                    .where((b) => b.period == 'weekly')
                                    .toList();

                                if (budgets.isEmpty) {
                                  return const Center(
                                    child: Text('No weekly budgets'),
                                  );
                                }

                                return ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: budgets.length,
                                  itemBuilder: (context, index) {
                                    return _buildWeeklyBudgetCard(
                                      budgets[index],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Cashflow Summary
                          Container(
                            padding: const EdgeInsets.all(16),
                            // decoration: BoxDecoration(
                            //   gradient: const LinearGradient(
                            //     colors: [Color(0xFF2B5BA6),Color(0xFFFFFF),Color(0xFF1E3A6D),],),
                            //   borderRadius: BorderRadius.circular(16),
                            // ),
                            decoration: BoxDecoration(
                              color: AppTheme.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.green),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Cashflow Summary',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.green,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.refresh, size: 20),
                                      onPressed: onRefresh,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      color: AppTheme.green,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        const Icon(
                                          Icons.arrow_downward,
                                          color: AppTheme.green,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          CurrencyFormatter.format(
                                            weeklyIncome,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.green,
                                          ),
                                        ),
                                        const Text(
                                          'Income',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        const Icon(
                                          Icons.arrow_upward,
                                          color: AppTheme.red,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          CurrencyFormatter.format(
                                            weeklyExpenses,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.red,
                                          ),
                                        ),
                                        const Text(
                                          'Expenses',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        const Icon(
                                          Icons.savings,
                                          color: AppTheme.primaryBlue,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          CurrencyFormatter.format(
                                            weeklyIncome - weeklyExpenses,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryBlue,
                                          ),
                                        ),
                                        const Text(
                                          'Saved',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Income Tracker
                          const Text(
                            'Income Tracker',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildIncomeCard(
                                'Gig Work',
                                stats['gigIncome'] ?? 0.0,
                                Icons.work,
                                Colors.purple,
                              ),
                              const SizedBox(width: 12),
                              _buildIncomeCard(
                                'Other',
                                0.0, // Would track other income
                                Icons.more_horiz,
                                Colors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

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

  String _getDateRange() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[weekStart.month - 1]} ${weekStart.day} - ${months[weekEnd.month - 1]} ${weekEnd.day}';
  }

  Stream<Map<String, dynamic>> _getStatsStream() {
    return _firebaseService.getTransactions().asyncMap((transactions) async {
      double totalIncome = 0;
      double totalExpenses = 0;
      double weeklyIncome = 0;
      double weeklyExpenses = 0;
      double salaryIncome = 0;
      double gigIncome = 0;
      double totalSavings = 0;

      DateTime now = DateTime.now();
      DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
      // Normalize to midnight
      weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);

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

  Stream<Map<String, double>> _getActualSpendingStream() {
    final now = DateTime.now();
    final weekStartRaw = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(
      weekStartRaw.year,
      weekStartRaw.month,
      weekStartRaw.day,
    );

    return _firebaseService.getTransactions().map((transactions) {
      final Map<String, double> categoryTotals = {};
      for (var transaction in transactions) {
        if (transaction.type == 'expense' &&
            transaction.date.isAfter(weekStart)) {
          categoryTotals[transaction.category] =
              (categoryTotals[transaction.category] ?? 0) +
              transaction.actualExpenseAmount;
        }
      }
      return categoryTotals;
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
            color: Colors.grey.withValues(alpha: 0.1),
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
          StreamBuilder<Map<String, double>>(
            stream: _getActualSpendingStream(),
            builder: (context, snapshot) {
              final actualSpent =
                  snapshot.data?[budget.category] ?? budget.spent;
              final isActuallyOverBudget = actualSpent > budget.amount;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CurrencyFormatter.format(actualSpent),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isActuallyOverBudget
                          ? AppTheme.red
                          : Colors.black87,
                    ),
                  ),
                  Text(
                    'of ${CurrencyFormatter.format(budget.amount)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(amount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
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
