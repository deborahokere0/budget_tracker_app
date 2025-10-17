import 'package:flutter/material.dart';
import '../../constants/category_constants.dart';
import '../../models/budget_model.dart';
import '../../models/rule_model.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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

  Future<void> _navigateToCreateAlert(String category) async {
    // Navigate to create alert rule with category pre-filled
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRuleScreen(
          ruleType: 'alert',
          // Pass category as a parameter - you'll need to modify AddRuleScreen to accept this
          existingRule: RuleModel(
            id: '',
            userId: _firebaseService.currentUserId!,
            name: '$category Budget Alert',
            type: 'alert',
            conditions: {'category': category, 'threshold': 0},
            actions: {'sendNotification': true},
            createdAt: DateTime.now(),
          ),
        ),
      ),
    );

    // Auto-refresh after returning
    if (result != null || mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {}); // Trigger rebuild to refresh data
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

    // Auto-refresh after returning
    if (result != null || mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {});
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
              final alertRules = ruleSnapshot.data
                  ?.where((r) => r.type == 'alert')
                  .toList() ??
                  [];

              // Create maps for quick lookup
              final budgetsByCategory = <String, BudgetModel>{};
              for (var budget in budgets) {
                budgetsByCategory[budget.category] = budget;
              }

              final alertsByCategory = <String, RuleModel>{};
              for (var rule in alertRules) {
                final category = rule.conditions['category'] as String?;
                if (category != null) {
                  alertsByCategory[category] = rule;
                }
              }

              // Separate tracked and untracked categories
              final trackedCategories = <String>[];
              final untrackedCategories = <String>[];

              for (var category in CategoryConstants.expenseCategories) {
                final budget = budgetsByCategory[category];
                final hasAlert = alertsByCategory.containsKey(category);
                final hasSpending = budget != null && budget.spent > 0;

                if (hasAlert || hasSpending || (budget != null && budget.amount > 0)) {
                  trackedCategories.add(category);
                } else {
                  untrackedCategories.add(category);
                }
              }

              // Sort alphabetically
              trackedCategories.sort();
              untrackedCategories.sort();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period indicator
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

                    // Tracked Categories
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
                        final budget = budgetsByCategory[category];
                        final alertRule = alertsByCategory[category];
                        return _buildBudgetCard(
                          category: category,
                          budget: budget,
                          alertRule: alertRule,
                          isDimmed: false,
                        );
                      }),
                      const SizedBox(height: 32),
                    ],

                    // Untracked Categories
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
                        'Create alert rules to start tracking these categories',
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
                          alertRule: null,
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
    required RuleModel? alertRule,
    required bool isDimmed,
  }) {
    final budgetAmount = budget?.amount ?? 0.0;
    final spent = budget?.spent ?? 0.0;
    final hasAlert = alertRule != null;
    final isOverBudget = budgetAmount > 0 && spent > budgetAmount;
    final hasSpendingNoAlert = spent > 0 && !hasAlert;

    // Calculate progress
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
          color: hasSpendingNoAlert
              ? AppTheme.red
              : isOverBudget
              ? AppTheme.red
              : Colors.grey[300]!,
          width: hasSpendingNoAlert || isOverBudget ? 2 : 1,
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
          // Header Row
          Row(
            children: [
              // Category Icon
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

              // Category Name & Alert Status
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
                    if (hasAlert)
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            size: 12,
                            color: AppTheme.green,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              alertRule.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.green,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'No alert set',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),

              // Edit Button
              IconButton(
                icon: Icon(
                  hasAlert ? Icons.edit : Icons.add_alert,
                  color: isDimmed ? Colors.grey : AppTheme.primaryBlue,
                  size: 20,
                ),
                onPressed: () {
                  if (hasAlert) {
                    _navigateToEditAlert(alertRule);
                  } else {
                    _navigateToCreateAlert(category);
                  }
                },
                tooltip: hasAlert ? 'Edit alert rule' : 'Create alert rule',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Warning for spending without alert
          if (hasSpendingNoAlert) ...[
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
                    onPressed: () => _navigateToCreateAlert(category),
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

          // Budget Amount Row
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

          // Spent Amount Row
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
                CurrencyFormatter.format(spent),
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

          // Progress Bar
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

          // Progress Text
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

          // Period type indicator
          if (budget != null) ...[
            const SizedBox(height: 8),
            Row(
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
                if (budget.linkedAlertRuleId != null) ...[
                  const SizedBox(width: 6),
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
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}