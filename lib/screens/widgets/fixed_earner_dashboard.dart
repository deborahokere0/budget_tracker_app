import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/budget_model.dart';
import '../../models/transaction_model.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../constants/category_constants.dart';
import '../transactions/add_transaction_screen.dart';
import 'budget_tracker_screen.dart';
import 'monthly_reset_manager.dart';
import '../../utils/financial_calculator.dart';

class FixedEarnerDashboard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRefresh;
  final FirebaseService _firebaseService = FirebaseService();

  FixedEarnerDashboard({
    super.key,
    required this.user,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final daysUntilPayday = FinancialCalculator.calculateDaysUntilPayday();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: StreamBuilder<List<BudgetModel>>(
          stream: _firebaseService.getBudgets(),
          builder: (context, budgetsSnapshot) {
            return StreamBuilder<List<TransactionModel>>(
              stream: _firebaseService.getTransactions(),
              builder: (context, transactionsSnapshot) {
                if (budgetsSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    transactionsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // === Data Processing ===
                final budgets = budgetsSnapshot.data ?? [];
                final transactions = transactionsSnapshot.data ?? [];

                double totalIncome = 0;
                double totalExpenses = 0;
                // double totalSavings = 0; // Unused in UI currently but good to have
                final Map<String, double> categorySpending = {};

                final now = DateTime.now();
                final startOfMonth = DateTime(now.year, now.month, 1);

                for (var t in transactions) {
                  if (t.type == 'income') {
                    totalIncome += t.amount;
                  } else if (t.type == 'expense') {
                    totalExpenses += t.actualExpenseAmount;

                    // Track spending for this month for Budget Cards
                    if (t.date.isAfter(
                      startOfMonth.subtract(const Duration(seconds: 1)),
                    )) {
                      categorySpending[t.category] =
                          (categorySpending[t.category] ?? 0) +
                          t.actualExpenseAmount;
                    }
                  }
                }

                final netAmount = totalIncome - totalExpenses;
                final safeToSpend = FinancialCalculator.calculateSafeToSpend(
                  netAmount,
                );

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonthlyResetManager(
                        userId: user.uid,
                        onAlertsEnabled: onRefresh,
                      ),

                      // === Header Section ===
                      Container(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          30,
                        ), // Extra bottom padding for overlap
                        color: AppTheme
                            .primaryBlue, // Simple background behind content? No, logic below uses Container
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
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.1),
                                    Colors.white.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.account_balance_wallet,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Available Amount',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    CurrencyFormatter.format(netAmount),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildHeaderStat(
                                          'Safe-to-Spend',
                                          safeToSpend,
                                          AppTheme.green,
                                          isCurrency: true,
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 40,
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildHeaderStat(
                                          'Next Pay Day',
                                          daysUntilPayday,
                                          Colors.white,
                                          isCurrency: false,
                                          suffix: ' days',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // === Main Content Area ===
                      Container(
                        transform: Matrix4.translationValues(
                          0,
                          -20,
                          0,
                        ), // Slight overlap
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Budget Tracker Header
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Monthly Budgets',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
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
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryBlue,
                                    ),
                                    child: const Text('See All'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              if (budgets.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 32,
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.pie_chart_outline,
                                          size: 48,
                                          color: Colors.grey[300],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No budgets set',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ...budgets.take(3).map((budget) {
                                  final actualSpent =
                                      categorySpending[budget.category] ?? 0.0;
                                  return _buildBudgetCard(budget, actualSpent);
                                }),

                              const SizedBox(height: 32),

                              // Quick Actions
                              const Text(
                                'Quick Actions',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildQuickActionCard(
                                      'Upcoming Bills',
                                      Icons.receipt_long,
                                      AppTheme.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildQuickActionCard(
                                      'Savings Goals',
                                      Icons.savings_outlined,
                                      Colors.purple,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              _buildActionButtons(context),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderStat(
    String label,
    dynamic value,
    Color valueColor, {
    bool isCurrency = false,
    String suffix = '',
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isCurrency ? CurrencyFormatter.format(value) : '$value$suffix',
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetCard(BudgetModel budget, double actualSpent) {
    final double budgetAmount = budget.amount;
    final double percentSpent = budgetAmount > 0
        ? (actualSpent / budgetAmount).clamp(0.0, 1.0)
        : 0.0;
    final bool isOverBudget = actualSpent > budgetAmount;
    final Color categoryColor = CategoryConstants.getColor(budget.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, categoryColor.withValues(alpha: 0.05)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isOverBudget
              ? AppTheme.red.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CategoryConstants.getIcon(budget.category),
                      color: categoryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    budget.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(actualSpent),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isOverBudget ? AppTheme.red : Colors.black87,
                    ),
                  ),
                  Text(
                    'of ${CurrencyFormatter.format(budgetAmount)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: percentSpent),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverBudget ? AppTheme.red : categoryColor,
                ),
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color.withValues(alpha: 0.8),
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
          child: _buildActionButton(
            context,
            'Add Income',
            Icons.arrow_downward,
            AppTheme.green,
            'income',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            context,
            'Add Expense',
            Icons.arrow_upward,
            AppTheme.red,
            'expense',
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    String type,
  ) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(
              onTransactionAdded: onRefresh,
              initialTransactionType: type,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: color.withValues(alpha: 0.4),
      ).copyWith(elevation: WidgetStateProperty.all(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
