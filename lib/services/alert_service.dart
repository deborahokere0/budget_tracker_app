import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rule_model.dart';
import '../models/transaction_model.dart';
import 'notification_service.dart';

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  AlertService(this.userId);

  // Get current month spending by category
  Future<Map<String, double>> getCurrentCategorySpending() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    print('DEBUG: Querying transactions for userId: $userId');
    print('DEBUG: Start of month: $startOfMonth');

    final snapshot = await _firestore
        .collection('transactions')
        .doc(userId)
        .collection('userTransactions')
        .where('type', isEqualTo: 'expense')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .get();

    print('DEBUG: Found ${snapshot.docs.length} expense transactions');

    Map<String, double> categoryTotals = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      print('DEBUG: Transaction data: $data');  // ADD THIS
      final transaction = TransactionModel.fromMap(doc.data());
      final category = transaction.category;

      categoryTotals[category] = (categoryTotals[category] ?? 0) + transaction.actualExpenseAmount;
    }

    print('DEBUG: Category totals: $categoryTotals');
    return categoryTotals;
  }

  // Stream of category spending (real-time)
  Stream<Map<String, double>> getCategorySpendingStream() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'expense')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .snapshots()
        .map((snapshot) {
      Map<String, double> categoryTotals = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String;
        final amount = (data['amount'] as num).toDouble();

        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      }
      return categoryTotals;
    });
  }

  // Check all active alert rules and trigger if needed
  Future<void> checkAndTriggerAlerts() async {
    try {
      // Get all active alert rules - FIXED PATH
      final rulesSnapshot = await _firestore
          .collection('rules')
          .doc(userId)  // Add this
          .collection('userRules')  // Add this
          .where('type', isEqualTo: 'alert')
          .where('isActive', isEqualTo: true)
          .get();

      if (rulesSnapshot.docs.isEmpty) {
        print('No active alert rules found');
        return;
      }
      final categorySpending = await getCurrentCategorySpending();
      print('Current category spending: $categorySpending');

      for (var doc in rulesSnapshot.docs) {
        final rule = RuleModel.fromMap(doc.data());
        await _checkSingleAlert(rule, categorySpending);
      }
    } catch (e) {
      print('Error checking alerts: $e');
    }
  }

  // Check a single alert rule
  Future<void> _checkSingleAlert(
      RuleModel rule,
      Map<String, double> categorySpending,
      ) async {
    final category = rule.conditions['category'] as String?;
    final threshold = (rule.conditions['threshold'] as num?)?.toDouble() ?? 0.0;

    if (category == null) {
      print('Alert rule ${rule.name} has no category');
      return;
    }

    final currentSpending = categorySpending[category] ?? 0.0;

    print('Checking alert: ${rule.name} | Category: $category | Spending: $currentSpending | Threshold: $threshold');

    // Check if threshold exceeded
    if (currentSpending >= threshold) {
      print('Threshold exceeded! Checking if should notify...');

      // Simplified notification logic
      final shouldNotify = await _shouldSendNotification(rule, currentSpending);

      if (shouldNotify) {
        print('Sending notification for ${rule.name}');

        // Send notification
        await NotificationService.sendAlertNotification(
          rule: rule,
          currentSpending: currentSpending,
        );

        // Update lastTriggered timestamp
        await _updateLastTriggered(rule.id);
        print('Notification sent and lastTriggered updated');
      } else {
        print('Notification blocked by shouldSendNotification logic');
      }
    } else {
      print('Threshold not exceeded, no alert needed');
    }
  }

  // Simplified: Determine if we should send notification
  Future<bool> _shouldSendNotification(RuleModel rule, double currentSpending) async {
    // If never triggered, always send notification
    if (rule.lastTriggered == null) {
      print('First time triggering, sending notification');
      return true;
    }

    // Check if last notification was more than 24 hours ago (daily reminder)
    final hoursSinceLastTrigger =
        DateTime.now().difference(rule.lastTriggered!).inHours;

    if (hoursSinceLastTrigger >= 0.01) {
      print('Last trigger was $hoursSinceLastTrigger hours ago, sending reminder');
      return true;
    }

    print('Last trigger was only $hoursSinceLastTrigger hours ago, skipping');
    return false;
  }

  // Update lastTriggered timestamp
  Future<void> _updateLastTriggered(String ruleId) async {
    try {
      await _firestore
          .collection('rules')
          .doc(userId)  // ADD THIS
          .collection('userRules')  // ADD THIS
          .doc(ruleId)
          .update({
        'lastTriggered': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating lastTriggered: $e');
    }
  }

  // Check alert immediately after a transaction - FIXED
  Future<void> checkAlertForTransaction(TransactionModel transaction) async {
    if (transaction.type != 'expense') {
      print('Not an expense, skipping alert check');
      return;
    }
    try {
      print('Checking alerts for transaction: ${transaction.description} (${transaction.category})');

      // FIXED: Correct path with userId
      final rulesSnapshot = await _firestore
          .collection('rules')
          .doc(userId)  // Add userId here
          .collection('userRules')  // Add subcollection
          .where('type', isEqualTo: 'alert')
          .where('isActive', isEqualTo: true)
          .get();

      if (rulesSnapshot.docs.isEmpty) {
        print('No active alert rules found');
        return;
      }
      // Filter rules by category in Dart code
      final matchingRules = rulesSnapshot.docs
          .map((doc) => RuleModel.fromMap(doc.data()))
          .where((rule) => rule.conditions['category'] == transaction.category)
          .toList();

      print('Found ${matchingRules.length} matching alert rules for ${transaction.category}');
      if (matchingRules.isEmpty) {
        print('No alert rules match category ${transaction.category}');
        return;
      }

      // Get current spending for this category
      final categorySpending = await getCurrentCategorySpending();
      print('Current spending for ${transaction.category}: ${categorySpending[transaction.category] ?? 0.0}');
      // Check each matching rule
      for (var rule in matchingRules) {
        await _checkSingleAlert(rule, categorySpending);
      }
    } catch (e) {
      print('Error checking alert for transaction: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // Check savings goal progress and notify
  Future<void> checkSavingsGoalProgress(RuleModel savingsRule) async {
    if (savingsRule.type != 'savings' || savingsRule.isPiggyBank == true) {
      return;
    }

    final progress = savingsRule.savingsProgress;
    final lastProgress = await _getLastNotifiedProgress(savingsRule.id);

    // Notify at 25%, 50%, 75%, and 100% milestones
    final milestones = [25.0, 50.0, 75.0, 100.0];

    for (var milestone in milestones) {
      if (progress >= milestone && lastProgress < milestone) {
        await NotificationService.sendSavingsGoalNotification(
          rule: savingsRule,
          progress: progress,
        );

        // Save this milestone
        await _saveProgressMilestone(savingsRule.id, milestone);
        break; // Only send one notification at a time
      }
    }
  }

  // Get last notified progress milestone
  Future<double> _getLastNotifiedProgress(String ruleId) async {
    try {
      final doc = await _firestore
          .collection('progress_milestones')
          .doc(ruleId)
          .get();

      if (doc.exists) {
        return (doc.data()?['lastMilestone'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      print('Error getting progress milestone: $e');
    }
    return 0.0;
  }

  // Save progress milestone
  Future<void> _saveProgressMilestone(String ruleId, double milestone) async {
    await _firestore
        .collection('progress_milestones')
        .doc(ruleId)
        .set({
      'lastMilestone': milestone,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Get triggered alerts for display
  Stream<List<Map<String, dynamic>>> getTriggeredAlertsStream() {
    return getCategorySpendingStream().asyncMap((spending) async {
      final rulesSnapshot = await _firestore
          .collection('rules')
          .doc(userId)  // ADD THIS
          .collection('userRules')  // ADD THIS
          .where('type', isEqualTo: 'alert')
          .where('isActive', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> triggeredAlerts = [];

      for (var doc in rulesSnapshot.docs) {
        final rule = RuleModel.fromMap(doc.data());
        final category = rule.conditions['category'] as String?;
        final threshold = (rule.conditions['threshold'] as num?)?.toDouble() ?? 0.0;

        if (category != null) {
          final currentSpending = spending[category] ?? 0.0;

          if (currentSpending >= threshold) {
            triggeredAlerts.add({
              'rule': rule,
              'currentSpending': currentSpending,
              'exceeded': currentSpending - threshold,
            });
          }
        }
      }

      return triggeredAlerts;
    });
  }
}