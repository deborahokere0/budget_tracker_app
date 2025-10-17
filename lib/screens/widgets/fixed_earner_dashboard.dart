import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/budget_model.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../transactions/add_transaction_screen.dart';
import '../widgets/enhanced_alert_banner.dart';
import 'budget_tracker_screen.dart';

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
    // Calculate days until next payday
    final now = DateTime.now();
    final nextPayday = DateTime(now.year, now.month + 1, 2);
    final daysUntilPayday = nextPayday.difference(now).inDays;

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
                  'totalIncome': 0.0,
                  'totalExpenses': 0.0,
                  'totalSavings': 0.0,
                };

            final netAmount = stats['netAmount'] ?? 0.0;
            final safeToSpend = netAmount > 0 ? netAmount * 0.3 : 0.0;

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
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available Amount',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
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
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Safe-to-Spend',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(safeToSpend),
                                          style: TextStyle(
                                            color: AppTheme.green,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Next Pay Day',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'In $daysUntilPayday days',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
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

                  EnhancedAlertBannersContainer(
                    userId: user.uid,
                    dashboardType: 'fixed',
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
                          // Monthly Budget Tracker
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Monthly Budget Tracker',
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
                          StreamBuilder<List<BudgetModel>>(
                            stream: _firebaseService.getBudgets(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final budgets = snapshot.data!.take(3).toList();

                              return Column(
                                children: budgets
                                    .map((budget) => _buildBudgetItem(budget))
                                    .toList(),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // Salary Alert
                          if (daysUntilPayday <= 10)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.orange),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning, color: AppTheme.orange),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Next salary drops in $daysUntilPayday days',
                                      style: TextStyle(color: AppTheme.orange),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Quick Actions
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickActionCard(
                                  'Upcoming Bills',
                                  Icons.receipt,
                                  Colors.blue[50]!,
                                  AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildQuickActionCard(
                                  'Saving Goals',
                                  Icons.savings,
                                  Colors.purple[50]!,
                                  Colors.purple,
                                ),
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

  Stream<Map<String, dynamic>> _getStatsStream() {
    return _firebaseService.getTransactions().asyncMap((transactions) async {
      double totalIncome = 0;
      double totalExpenses = 0;
      double totalSavings = 0;

      for (var transaction in transactions) {
        if (transaction.type == 'income') {
          totalIncome += transaction.amount;
        } else if (transaction.type == 'expense') {
          totalExpenses += transaction.actualExpenseAmount;

          if (transaction.hasSavingsAllocation) {
            totalSavings += transaction.savingsAllocation!;
          }
        }
      }

      return {
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'totalSavings': totalSavings,
        'netAmount': totalIncome - totalExpenses,
      };
    });
  }

  Widget _buildBudgetItem(BudgetModel budget) {
    final percentSpent = budget.percentSpent.clamp(0, 100);
    final isOverBudget = budget.spent > budget.amount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budget.category,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${CurrencyFormatter.format(budget.spent)}/${CurrencyFormatter.format(budget.amount)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isOverBudget ? AppTheme.red : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentSpent / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isOverBudget ? AppTheme.red : AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color bgColor,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
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
}
