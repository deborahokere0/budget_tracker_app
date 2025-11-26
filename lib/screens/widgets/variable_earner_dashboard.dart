import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/budget_model.dart';
import '../../models/rule_model.dart';
import '../../services/firebase_service.dart';
import '../../services/income_allocation_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../constants/category_constants.dart';
import '../transactions/add_transaction_screen.dart';
import '../rules/add_rule_screen.dart';
import 'budget_tracker_screen.dart';
import 'monthly_reset_manager.dart';

class VariableEarnerDashboard extends StatefulWidget {
  final UserModel user;
  final Map<String, dynamic> stats;
  final VoidCallback onRefresh;

  const VariableEarnerDashboard({
    super.key,
    required this.user,
    required this.onRefresh,
    required this.stats,
  });

  @override
  State<VariableEarnerDashboard> createState() =>
      _VariableEarnerDashboardState();
}

class _VariableEarnerDashboardState extends State<VariableEarnerDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  late final IncomeAllocationService _allocationService;

  Map<String, dynamic> _weeklyStats = {};
  List<RuleModel> _allocationRules = [];
  List<Map<String, dynamic>> _weeklyBudgets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _allocationService = IncomeAllocationService(widget.user.uid);
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Check for weekly reset (if Monday)
      await _firebaseService.checkAndPerformWeeklyReset();

      // Load weekly stats
      final stats = await _firebaseService.getVariableEarnerWeeklyStats();

      // Load allocation rules
      final rules = await _firebaseService.getIncomeAllocationRules().first;

      // Get allocation summary
      final allocationSummary = await _allocationService
          .getWeeklyAllocationSummary();

      setState(() {
        _weeklyStats = {...stats, ...allocationSummary};
        _allocationRules = rules.where((r) => r.isActive).toList();
        _weeklyBudgets = stats['weeklyBudgets'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadDashboardData();
          widget.onRefresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonthlyResetManager(
                userId: widget.user.uid,
                onAlertsEnabled: widget.onRefresh,
              ),
              _buildHeader(),
              _buildWeeklySummaryCard(),
              _buildIncomeAllocationSection(),
              _buildWeeklyBudgetsSection(),
              _buildQuickActionsSection(),
              _buildIncomeSourceBreakdown(),
              _buildAllocationRulesSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final runwayWeeks = _weeklyStats['runwayWeeks'] ?? 0;
    final runwayStatus = _weeklyStats['runwayStatus'] ?? 'UNKNOWN';

    return Container(
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
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Net Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
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
                  CurrencyFormatter.format(_weeklyStats['netWeekly'] ?? 0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatColumn(
                      'Earned',
                      _weeklyStats['weeklyIncome'] ?? 0,
                    ),
                    _buildStatColumn(
                      'Spent',
                      _weeklyStats['weeklyExpenses'] ?? 0,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'RUNWAY PERIOD',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: runwayStatus == 'HEALTHY'
                                  ? Colors.green
                                  : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$runwayWeeks weeks',
                              style: TextStyle(
                                color: runwayStatus == 'HEALTHY'
                                    ? Colors.green
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
    );
  }

  Widget _buildWeeklySummaryCard() {
    final weeklyIncome = _weeklyStats['weeklyIncome'] ?? 0.0;
    final weeklyExpenses = _weeklyStats['weeklyExpenses'] ?? 0.0;
    final incomeVolatility = _weeklyStats['incomeVolatility'] ?? 'STABLE';
    final incomeChangePercent = _weeklyStats['incomeChangePercent'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: incomeVolatility == 'HIGH'
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      incomeChangePercent > 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      color: incomeChangePercent > 0
                          ? Colors.green
                          : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${incomeChangePercent.abs().toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: incomeChangePercent > 0
                            ? Colors.green
                            : Colors.red,
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
    );
  }

  Widget _buildIncomeAllocationSection() {
    final totalAllocated = _weeklyStats['totalAllocated'] ?? 0.0;
    final unallocated = _weeklyStats['unallocated'] ?? 0.0;
    final weeklyIncome = _weeklyStats['weeklyIncome'] ?? 0.0;

    if (weeklyIncome == 0) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No income recorded this week. Add income to start auto-allocation.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    final allocationPercent = weeklyIncome > 0
        ? (totalAllocated / weeklyIncome * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withOpacity(0.1),
            AppTheme.green.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Auto-Allocation Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${allocationPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: allocationPercent / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                allocationPercent > 80 ? Colors.green : AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allocated',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    CurrencyFormatter.format(totalAllocated),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Unallocated',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    CurrencyFormatter.format(unallocated),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBudgetsSection() {
    if (_weeklyBudgets.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No weekly budgets yet',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddRuleScreen(ruleType: 'allocation'),
                    ),
                  ).then((result) {
                    if (result == true) {
                      _loadDashboardData();
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
                child: const Text(
                  'Create Allocation Rule',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Budgets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BudgetTrackerScreen()),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _weeklyBudgets.length,
              itemBuilder: (context, index) {
                final budgetData = _weeklyBudgets[index];
                final budget = budgetData['budget'] as BudgetModel;
                final actualSpent = budgetData['actualSpent'] as double;
                final percentUsed = budgetData['percentUsed'] as double;

                return _buildBudgetCard(budget, actualSpent, percentUsed);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(
    BudgetModel budget,
    double actualSpent,
    double percentUsed,
  ) {
    final isOverBudget = actualSpent > budget.amount;

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverBudget ? Colors.red.withOpacity(0.3) : Colors.grey[300]!,
          width: isOverBudget ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _getCategoryIcon(budget.category),
                style: const TextStyle(fontSize: 24),
              ),
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
            CurrencyFormatter.format(actualSpent),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isOverBudget ? AppTheme.red : Colors.black87,
            ),
          ),
          Text(
            'of ${CurrencyFormatter.format(budget.amount)}',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Add Income',
                  Icons.arrow_downward,
                  Colors.green,
                  () => _navigateToAddTransaction('income'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Add Expense',
                  Icons.arrow_upward,
                  Colors.red,
                  () => _navigateToAddTransaction('expense'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Navigate to Budget Tracker
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetTrackerScreen()),
              ).then((result) {
                _loadDashboardData();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'View Budget Tracker',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon), const SizedBox(width: 8), Text(label)],
      ),
    );
  }

  Widget _buildIncomeSourceBreakdown() {
    final sourceBreakdown =
        _weeklyStats['sourceBreakdown'] as Map<String, double>? ?? {};

    if (sourceBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Income Sources',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...sourceBreakdown.entries.map((entry) {
            final total = sourceBreakdown.values.reduce((a, b) => a + b);
            final percentage = total > 0 ? (entry.value / total * 100) : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    CategoryConstants.getIcon(entry.key),
                    size: 20,
                    color: CategoryConstants.getColor(entry.key),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(entry.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            minHeight: 4,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              CategoryConstants.getColor(entry.key),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAllocationRulesSection() {
    if (_allocationRules.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Allocation Rules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to rules screen
                },
                child: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._allocationRules.map((rule) {
            final allocationText = rule.allocationType == 'percentage'
                ? '${rule.allocationValue?.toStringAsFixed(0)}%'
                : CurrencyFormatter.format(rule.allocationValue ?? 0);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: rule.isActive
                    ? Colors.green.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: rule.isActive
                      ? Colors.green.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: rule.isActive ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${rule.incomeSource == "all" ? "All income" : rule.incomeSource} → '
                          '$allocationText to ${rule.targetCategory}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (rule.weeklyAllocatedAmount != null &&
                            rule.weeklyAllocatedAmount! > 0)
                          Text(
                            'This week: ${CurrencyFormatter.format(rule.weeklyAllocatedAmount!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          CurrencyFormatter.format(amount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getDateRange() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return '${weekStart.day}-${weekEnd.day} ${_getMonthName(weekStart.month)}';
  }

  String _getMonthName(int month) {
    const months = [
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
    return months[month - 1];
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

  void _navigateToAddTransaction(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          onTransactionAdded: () {
            _loadDashboardData();
            widget.onRefresh();
          },
          initialTransactionType: type,
        ),
      ),
    );
  }
}
