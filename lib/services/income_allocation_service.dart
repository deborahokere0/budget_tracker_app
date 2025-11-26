import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/rule_model.dart';
import '../models/budget_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class IncomeAllocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  IncomeAllocationService(this.userId);

  /// Process income transaction and apply allocation rules
  Future<Map<String, double>> processIncomeTransaction(
    TransactionModel transaction,
    UserModel user,
  ) async {
    if (transaction.type != 'income') {
      return {};
    }

    print(
      'Processing income transaction: ${transaction.description} - ${transaction.category}',
    );

    // Get all active income allocation rules
    final rules = await _getActiveIncomeAllocationRules();

    if (rules.isEmpty) {
      print('No active income allocation rules found');
      return {};
    }

    // Sort rules by priority (higher priority first)
    rules.sort((a, b) => b.priority.compareTo(a.priority));

    // Track allocations
    Map<String, double> allocations = {};
    double remainingIncome = transaction.amount;

    // Apply each rule
    for (var rule in rules) {
      if (remainingIncome <= 0) break;

      // Check if rule applies to this income source
      if (!rule.appliesToIncomeSource(transaction.category)) {
        continue;
      }

      // Calculate allocation amount
      double allocationAmount = rule.calculateAllocation(transaction.amount);

      // Don't allocate more than remaining
      if (allocationAmount > remainingIncome) {
        allocationAmount = remainingIncome;
      }

      if (allocationAmount > 0 && rule.targetCategory != null) {
        // Add to allocations map
        allocations[rule.targetCategory!] =
            (allocations[rule.targetCategory!] ?? 0) + allocationAmount;

        remainingIncome -= allocationAmount;

        // Update rule's weekly tracking
        await _updateRuleWeeklyAllocation(rule, allocationAmount);

        print(
          'Applied rule "${rule.name}": Allocated $allocationAmount to ${rule.targetCategory}',
        );
      }
    }

    // Create or update budgets based on allocations
    if (allocations.isNotEmpty) {
      await _createOrUpdateBudgets(allocations, user);

      // Send notification about allocations
      await _notifyAllocations(allocations, transaction);
    }

    return allocations;
  }

  /// Apply a specific rule to all income from the current week
  /// Used when a new rule is created to retroactively apply it
  Future<void> applyRuleToWeeklyIncome(RuleModel rule) async {
    final user = await _firestore
        .collection('users')
        .doc(userId)
        .get()
        .then((doc) => UserModel.fromMap(doc.data()!));
    final weekStart = _getWeekStart(DateTime.now());

    // Get all income transactions for current week
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .doc(userId)
        .collection('userTransactions')
        .where('type', isEqualTo: 'income')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get();

    double totalAllocated = 0;

    for (var doc in transactionsSnapshot.docs) {
      final transaction = TransactionModel.fromMap(doc.data());

      // Check if rule applies
      if (!rule.appliesToIncomeSource(transaction.category)) {
        continue;
      }

      // Calculate allocation amount
      double allocationAmount = rule.calculateAllocation(transaction.amount);

      if (allocationAmount > 0) {
        totalAllocated += allocationAmount;
      }
    }

    if (totalAllocated > 0 && rule.targetCategory != null) {
      // Update rule's weekly tracking
      await _updateRuleWeeklyAllocation(rule, totalAllocated);

      // Create/Update budget
      await _createOrUpdateBudgets({
        rule.targetCategory!: totalAllocated,
      }, user);

      print(
        'Retroactively applied rule "${rule.name}": Allocated $totalAllocated to ${rule.targetCategory}',
      );
    }
  }

  /// Get all active income allocation rules
  Future<List<RuleModel>> _getActiveIncomeAllocationRules() async {
    final snapshot = await _firestore
        .collection('rules')
        .doc(userId)
        .collection('userRules')
        .where('type', isEqualTo: 'income_allocation')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) => RuleModel.fromMap(doc.data())).toList();
  }

  /// Update rule's weekly allocation tracking
  Future<void> _updateRuleWeeklyAllocation(
    RuleModel rule,
    double allocationAmount,
  ) async {
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);

    // Check if we need to reset weekly tracking
    double newWeeklyAmount = allocationAmount;
    if (rule.weekStartDate != null && !rule.needsWeeklyReset()) {
      newWeeklyAmount += rule.weeklyAllocatedAmount ?? 0;
    }

    await _firestore
        .collection('rules')
        .doc(userId)
        .collection('userRules')
        .doc(rule.id)
        .update({
          'weeklyAllocatedAmount': newWeeklyAmount,
          'weekStartDate': weekStart.toIso8601String(),
          'lastTriggered': now.toIso8601String(),
        });
  }

  /// Create or update budgets based on allocations
  Future<void> _createOrUpdateBudgets(
    Map<String, double> allocations,
    UserModel user,
  ) async {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;
    String period;

    // Determine period based on income type
    if (user.incomeType == 'variable') {
      // Variable -> Weekly
      period = 'weekly';
      startDate = _getWeekStart(now);
      endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59));
    } else {
      // Fixed or Hybrid -> Monthly
      period = 'monthly';
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }

    for (var entry in allocations.entries) {
      final category = entry.key;
      final amount = entry.value;

      // Check if budget exists for this category and period
      final existingBudgetQuery = await _firestore
          .collection('budgets')
          .doc(userId)
          .collection('userBudgets')
          .where('category', isEqualTo: category)
          .where('period', isEqualTo: period)
          .where(
            'startDate',
            isGreaterThanOrEqualTo: startDate.toIso8601String(),
          )
          .limit(1)
          .get();

      if (existingBudgetQuery.docs.isNotEmpty) {
        // Update existing budget
        final existingDoc = existingBudgetQuery.docs.first;
        final existingBudget = BudgetModel.fromMap(existingDoc.data());

        await _firestore
            .collection('budgets')
            .doc(userId)
            .collection('userBudgets')
            .doc(existingDoc.id)
            .update({'amount': existingBudget.amount + amount});

        print('Updated $period budget for $category: +$amount');
      } else {
        // Create new budget
        final newBudgetId = _firestore
            .collection('budgets')
            .doc(userId)
            .collection('userBudgets')
            .doc()
            .id;

        final newBudget = BudgetModel(
          id: newBudgetId,
          userId: userId,
          category: category,
          amount: amount,
          spent: 0,
          period: period,
          startDate: startDate,
          endDate: endDate,
          isAutoCreated: true,
        );

        await _firestore
            .collection('budgets')
            .doc(userId)
            .collection('userBudgets')
            .doc(newBudgetId)
            .set(newBudget.toMap());

        print('Created $period budget for $category: $amount');

        // Check if there's an alert rule for this category
        await _createAlertForBudget(category, amount);
      }
    }
  }

  /// Create alert for newly created budget if alert rule exists
  Future<void> _createAlertForBudget(
    String category,
    double budgetAmount,
  ) async {
    // Check if user has alert rules for this category
    final alertRulesQuery = await _firestore
        .collection('rules')
        .doc(userId)
        .collection('userRules')
        .where('type', isEqualTo: 'alert')
        .where('conditions.category', isEqualTo: category)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (alertRulesQuery.docs.isNotEmpty) {
      print('Alert rule already exists for $category');
      return;
    }

    // Create default alert at 80% threshold
    final alertId = _firestore
        .collection('rules')
        .doc(userId)
        .collection('userRules')
        .doc()
        .id;

    final alertRule = RuleModel(
      id: alertId,
      userId: userId,
      name: '$category Budget Alert',
      type: 'alert',
      conditions: {
        'category': category,
        'thresholdType': 'percentage',
        'thresholdValue': 80,
      },
      actions: {
        'notificationType': 'push',
        'message': 'You have spent 80% of your $category budget',
      },
      priority: 1,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('rules')
        .doc(userId)
        .collection('userRules')
        .doc(alertId)
        .set(alertRule.toMap());

    print('Created default alert rule for $category at 80% threshold');
  }

  /// Send notification about allocations
  Future<void> _notifyAllocations(
    Map<String, double> allocations,
    TransactionModel transaction,
  ) async {
    String allocationSummary = allocations.entries
        .map((e) => '${e.key}: ₦${e.value.toStringAsFixed(2)}')
        .join(', ');

    await NotificationService.sendReminderNotification(
      title: '💰 Income Allocated',
      body: 'From ${transaction.description}: $allocationSummary',
    );
  }

  /// Get week start (Monday)
  DateTime _getWeekStart(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Check and reset weekly allocations on Monday
  Future<void> checkAndResetWeeklyAllocations() async {
    final now = DateTime.now();

    // Only reset on Mondays
    if (now.weekday != DateTime.monday) {
      return;
    }

    // Check last reset
    final lastResetDoc = await _firestore
        .collection('allocation_resets')
        .doc(userId)
        .get();

    if (lastResetDoc.exists) {
      final lastReset = DateTime.parse(
        lastResetDoc.data()?['lastReset'] ?? '2020-01-01',
      );

      // If already reset this week, skip
      if (_getWeekStart(lastReset) == _getWeekStart(now)) {
        return;
      }
    }

    print('Performing weekly allocation reset...');

    // Reset all income allocation rules' weekly amounts
    final rulesSnapshot = await _firestore
        .collection('rules')
        .doc(userId)
        .collection('userRules')
        .where('type', isEqualTo: 'income_allocation')
        .get();

    final batch = _firestore.batch();

    for (var doc in rulesSnapshot.docs) {
      batch.update(doc.reference, {
        'weeklyAllocatedAmount': 0,
        'weekStartDate': _getWeekStart(now).toIso8601String(),
      });
    }

    // Update last reset timestamp
    batch.set(
      _firestore.collection('allocation_resets').doc(userId),
      {
        'lastReset': now.toIso8601String(),
        'weekStart': _getWeekStart(now).toIso8601String(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    print('Weekly allocation reset completed');
  }

  /// Get summary of weekly allocations
  Future<Map<String, dynamic>> getWeeklyAllocationSummary() async {
    final weekStart = _getWeekStart(DateTime.now());

    // Get all income transactions for current week
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .doc(userId)
        .collection('userTransactions')
        .where('type', isEqualTo: 'income')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get();

    double totalIncome = 0;
    double totalAllocated = 0;
    Map<String, double> categoryAllocations = {};
    Map<String, double> sourceBreakdown = {};

    for (var doc in transactionsSnapshot.docs) {
      final transaction = TransactionModel.fromMap(doc.data());
      totalIncome += transaction.amount;

      // Track source breakdown
      sourceBreakdown[transaction.category] =
          (sourceBreakdown[transaction.category] ?? 0) + transaction.amount;
    }

    // Get allocation rules to calculate total allocated
    final rulesSnapshot = await _firestore
        .collection('rules')
        .doc(userId)
        .collection('userRules')
        .where('type', isEqualTo: 'income_allocation')
        .where('isActive', isEqualTo: true)
        .get();

    for (var doc in rulesSnapshot.docs) {
      final rule = RuleModel.fromMap(doc.data());
      if (rule.weeklyAllocatedAmount != null) {
        totalAllocated += rule.weeklyAllocatedAmount!;
        if (rule.targetCategory != null) {
          categoryAllocations[rule.targetCategory!] =
              (categoryAllocations[rule.targetCategory!] ?? 0) +
              rule.weeklyAllocatedAmount!;
        }
      }
    }

    return {
      'totalIncome': totalIncome,
      'totalAllocated': totalAllocated,
      'unallocated': totalIncome - totalAllocated,
      'categoryAllocations': categoryAllocations,
      'sourceBreakdown': sourceBreakdown,
      'weekStart': weekStart.toIso8601String(),
    };
  }
}
