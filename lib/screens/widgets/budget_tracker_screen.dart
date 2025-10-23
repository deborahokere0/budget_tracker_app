import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants/category_constants.dart';
import '../../models/budget_model.dart';
import '../../models/rule_model.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../rules/add_rule_screen.dart';

class BudgetTrackerScreen extends StatefulWidget {
  const BudgetTrackerScreen({super.key});

  @override
  State<BudgetTrackerScreen> createState() => _BudgetTrackerScreenState();
}

class _BudgetTrackerScreenState extends State<BudgetTrackerScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  UserModel? _currentUser;
  bool _isLoading = true;
  Map<String, double> _actualSpending = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadActualSpending();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await _firebaseService.getUserProfile(
        _firebaseService.currentUserId!,
      );
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateToCreateAllocation(String category) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRuleScreen(
          ruleType: 'allocation',
          prefilledCategory: category,
        ),
      ),
    );

    if (result != null || mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadActualSpending();
      setState(() {});
    }
  }

  Future<void> _navigateToEditAllocation(RuleModel allocationRule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRuleScreen(
          ruleType: 'allocation',
          existingRule: allocationRule,
        ),
      ),
    );

    if (result != null || mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadActualSpending();
      setState(() {});
    }
  }

  Future<void> _showAlertsBottomSheet(
      String category,
      BudgetModel? budget,
      List<RuleModel> alertRules,
      ) async {
    if (budget == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Alerts for $category Budget',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Budget Amount',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(budget.amount),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Current Spending',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(budget.spent),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: budget.spent > budget.amount
                                  ? AppTheme.red
                                  : AppTheme.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (alertRules.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notifications_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No alerts set for this budget',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...alertRules.map((alert) {
                    final thresholdType =
                    alert.conditions['thresholdType'] as String?;
                    final thresholdValue =
                        (alert.conditions['thresholdValue'] as num?)
                            ?.toDouble() ??
                            0.0;

                    double thresholdAmount = thresholdValue;
                    if (thresholdType == 'percentage') {
                      thresholdAmount = budget.amount * (thresholdValue / 100);
                    }

                    bool isTriggered = budget.spent >= thresholdAmount;
                    bool isPassed = alert.lastTriggered != null &&
                        budget.spent < thresholdAmount;

                    String status = 'Active';
                    Color statusColor = AppTheme.green;
                    IconData statusIcon = Icons.check_circle;

                    if (!alert.isActive) {
                      status = 'Inactive';
                      statusColor = Colors.grey;
                      statusIcon = Icons.cancel;
                    } else if (isTriggered) {
                      status = 'TRIGGERED';
                      statusColor = AppTheme.red;
                      statusIcon = Icons.error;
                    } else if (isPassed) {
                      status = 'Passed';
                      statusColor = Colors.grey;
                      statusIcon = Icons.check_circle_outline;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alert.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(alert.priority)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Priority ${alert.priority}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _getPriorityColor(alert.priority),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Threshold',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      thresholdType == 'percentage'
                                          ? '${thresholdValue.toStringAsFixed(0)}% (${CurrencyFormatter.format(thresholdAmount)})'
                                          : CurrencyFormatter.format(
                                          thresholdValue),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (alert.lastTriggered != null)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Last Triggered',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        _getTimeAgo(alert.lastTriggered!),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _navigateToEditAlert(alert);
                                  },
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Edit'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final confirm = await _confirmDelete(
                                      context,
                                      alert.name,
                                    );
                                    if (confirm == true) {
                                      await _firebaseService.deleteRule(
                                        alert.id,
                                      );
                                      Navigator.pop(context);
                                      setState(() {});
                                    }
                                  },
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('Delete'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _navigateToCreateAlert(category);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Alert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    setState(() {});
  }

  Future<void> _navigateToCreateAlert(String category) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRuleScreen(
          ruleType: 'alert',
          prefilledCategory: category,
        ),
      ),
    );

    if (result != null || mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadActualSpending();
      setState(() {});
    }
  }

  Future<void> _navigateToEditAlert(RuleModel alertRule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRuleScreen(
          ruleType: 'alert',
          existingRule: alertRule,
        ),
      ),
    );

    if (result != null || mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadActualSpending();
      setState(() {});
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alert'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadActualSpending() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(_firebaseService.currentUserId)
          .collection('userTransactions')
          .where('type', isEqualTo: 'expense')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      final Map<String, double> categoryTotals = {};
      for (var doc in snapshot.docs) {
        final transaction = TransactionModel.fromMap(doc.data());
        categoryTotals[transaction.category] =
            (categoryTotals[transaction.category] ?? 0) + transaction.actualExpenseAmount;
      }

      if (mounted) {
        setState(() => _actualSpending = categoryTotals);
      }
    } catch (e) {
      print('Error loading actual spending: $e');
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 5:
        return AppTheme.red;
      case 4:
        return AppTheme.orange;
      case 3:
        return Colors.amber;
      case 2:
        return AppTheme.primaryBlue;
      default:
        return Colors.grey;
    }
  }

  String _getPeriodText() {
    if (_currentUser == null) return 'Monthly';

    switch (_currentUser!.incomeType) {
      case 'variable':
      case 'hybrid':
        return 'Weekly';
      case 'fixed':
      default:
        return 'Monthly';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Budget Tracker'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${_getPeriodText()} Budgets'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<BudgetModel>>(
        stream: _firebaseService.getBudgets(),
        builder: (context, budgetSnapshot) {
          return StreamBuilder<List<RuleModel>>(
            stream: _firebaseService.getRules(),
            builder: (context, ruleSnapshot) {
              if (budgetSnapshot.connectionState == ConnectionState.waiting ||
                  ruleSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final budgets = budgetSnapshot.data ?? [];
              final allRules = ruleSnapshot.data ?? [];
              final allocationRules =
              allRules.where((r) => r.type == 'allocation').toList();
              final alertRules =
              allRules.where((r) => r.type == 'alert').toList();

              final budgetsByCategory = <String, BudgetModel>{};
              for (var budget in budgets) {
                budgetsByCategory[budget.category] = budget;
              }

              final allocationsByCategory = <String, RuleModel>{};
              for (var rule in allocationRules) {
                final category = rule.conditions['category'] as String?;
                if (category != null) {
                  allocationsByCategory[category] = rule;
                }
              }

              final alertsByCategory = <String, List<RuleModel>>{};
              for (var rule in alertRules) {
                final category = rule.conditions['category'] as String?;
                if (category != null) {
                  alertsByCategory[category] =
                  [...(alertsByCategory[category] ?? []), rule];
                }
              }

              final trackedCategories = <String>[];
              final untrackedCategories = <String>[];

              for (var category in CategoryConstants.expenseCategories) {
                final budget = budgetsByCategory[category];
                final hasAllocation = allocationsByCategory.containsKey(category);
                final hasSpending = budget != null && budget.spent > 0;
                final hasBudgetAmount = budget != null && budget.amount > 0;

                if (hasAllocation || hasBudgetAmount || hasSpending ||
                    (budget != null && budget.amount > 0)) {
                  trackedCategories.add(category);
                } else {
                  untrackedCategories.add(category);
                }
              }

              trackedCategories.sort();
              untrackedCategories.sort();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryBlue),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_getPeriodText()} Budget Period',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (trackedCategories.isNotEmpty) ...[
                      const Text(
                        'Active Budgets',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...trackedCategories.map((category) {
                        return _buildBudgetCard(
                          category: category,
                          budget: budgetsByCategory[category],
                          allocationRule: allocationsByCategory[category],
                          alertRules: alertsByCategory[category] ?? [],
                          isDimmed: false,
                        );
                      }),
                      const SizedBox(height: 32),
                    ],

                    if (untrackedCategories.isNotEmpty) ...[
                      const Text(
                        'Untracked Categories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No budget set, auto-allocate your budget',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...untrackedCategories.map((category) {
                        return _buildBudgetCard(
                          category: category,
                          budget: null,
                          allocationRule: null,
                          alertRules: [],
                          isDimmed: true,
                        );
                      }),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBudgetCard({
    required String category,
    required BudgetModel? budget,
    required RuleModel? allocationRule,
    required List<RuleModel> alertRules,
    required bool isDimmed,
  }) {
    final budgetAmount = budget?.amount ?? 0.0;
    final spent = budget?.spent ?? _actualSpending[category] ?? 0.0;
    final hasAllocation = allocationRule != null;
    final isOverBudget = budgetAmount > 0 && spent > budgetAmount;
    final hasSpendingNoAllocation = spent > 0 && !hasAllocation;

    double progress = 0.0;
    if (budgetAmount > 0) {
      progress = (spent / budgetAmount).clamp(0.0, 1.0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDimmed ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSpendingNoAllocation
              ? AppTheme.red
              : isOverBudget
              ? AppTheme.red
              : Colors.grey[300]!,
          width: hasSpendingNoAllocation || isOverBudget ? 2 : 1,
        ),
        boxShadow: isDimmed
            ? null
            : [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CategoryConstants.getColor(category)
                      .withValues(alpha: isDimmed ? 0.3 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  CategoryConstants.getIcon(category),
                  color: isDimmed
                      ? Colors.grey
                      : CategoryConstants.getColor(category),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDimmed ? Colors.grey : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (hasAllocation)
                      Row(
                        children: [
                          Icon(
                            Icons.rule,
                            size: 12,
                            color: allocationRule.isActive
                                ? AppTheme.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              allocationRule.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: allocationRule.isActive
                                    ? AppTheme.green
                                    : Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'No budget set',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),

              if (budget != null || hasAllocation)
                GestureDetector(
                  onTap: () {
                    if (budget != null) {
                      _showAlertsBottomSheet(category, budget, alertRules);
                    } else {
                      _navigateToCreateAlert(category);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (alertRules.isNotEmpty ? AppTheme.red : AppTheme.primaryBlue)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: alertRules.isNotEmpty ? AppTheme.red : AppTheme.primaryBlue,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          alertRules.isNotEmpty ? Icons.notifications_active : Icons.add_alert,
                          size: 14,
                          color: alertRules.isNotEmpty ? AppTheme.red : AppTheme.primaryBlue,
                        ),
                        if (alertRules.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${alertRules.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  hasAllocation ? Icons.edit : Icons.add,
                  color: isDimmed ? Colors.grey : AppTheme.primaryBlue,
                  size: 20,
                ),
                onPressed: () {
                  if (hasAllocation) {
                    _navigateToEditAllocation(allocationRule);
                  } else {
                    _navigateToCreateAllocation(category);
                  }
                },
                tooltip: hasAllocation
                    ? 'Edit allocation rule'
                    : 'Create allocation rule',
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (hasSpendingNoAllocation) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.red),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: AppTheme.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Untracked Spending',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.red,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Set budget to track this',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _navigateToCreateAllocation(category),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: AppTheme.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text(
                      'Set Budget',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget',
                style: TextStyle(
                  fontSize: 12,
                  color: isDimmed ? Colors.grey : Colors.grey[600],
                ),
              ),
              Text(
                CurrencyFormatter.format(budgetAmount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDimmed ? Colors.grey : Colors.black,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent',
                style: TextStyle(
                  fontSize: 12,
                  color: isDimmed ? Colors.grey : Colors.grey[600],
                ),
              ),
              Text(
                CurrencyFormatter.format(budget?.spent ?? _actualSpending[category] ?? 0.0),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDimmed
                      ? Colors.grey
                      : isOverBudget
                      ? AppTheme.red
                      : Colors.black,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isDimmed
                  ? Colors.grey
                  : isOverBudget
                  ? AppTheme.red
                  : AppTheme.primaryBlue,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budgetAmount > 0
                    ? '${(progress * 100).toStringAsFixed(0)}% used'
                    : 'No budget set',
                style: TextStyle(
                  fontSize: 11,
                  color: isDimmed ? Colors.grey : Colors.grey[600],
                ),
              ),
              if (budgetAmount > 0)
                Text(
                  '${CurrencyFormatter.format((budgetAmount - spent).abs())} ${spent > budgetAmount ? 'over' : 'left'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDimmed
                        ? Colors.grey
                        : isOverBudget
                        ? AppTheme.red
                        : AppTheme.green,
                  ),
                ),
            ],
          ),

          if (budget != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    budget.period.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                if (budget.linkedAlertRuleId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'AUTO-SYNCED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.green,
                      ),
                    ),
                  ),
                if (alertRules.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications,
                          size: 10,
                          color: AppTheme.orange,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${alertRules.length} alert${alertRules.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          if (isDimmed && !hasAllocation) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'No budget set, auto-allocate your budget',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}