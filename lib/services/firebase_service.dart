import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/rule_model.dart';
import 'alert_service.dart';
import 'notification_service.dart';
import 'income_allocation_service.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  // ========== IMPROVED MONTHLY RESET SYSTEM ==========

  /// Check and perform monthly reset if needed (call this on app startup)
  Future<void> checkAndPerformMonthlyReset() async {
    print('=== MONTHLY RESET CHECK START ===');
    print('Current User ID: $currentUserId');

    if (currentUserId == null) {
      print('No user ID - skipping reset');
      return;
    }

    try {
      print('Checking if monthly reset is needed...');

      final shouldReset = await _shouldResetThisMonth();
      print('Should reset? $shouldReset');

      if (shouldReset) {
        print('✅ PERFORMING MONTHLY RESET...');
        await _performMonthlyReset();
        await _saveResetTimestamp();
        print('✅ Monthly reset completed successfully');
      } else {
        print('⏭️ Monthly reset already performed this month');
      }
    } catch (e, stackTrace) {
      print('❌ Error during monthly reset check: $e');
      print('Stack trace: $stackTrace');
      // Don't throw - allow app to continue even if reset fails
    }

    print('=== MONTHLY RESET CHECK END ===');
  }

  /// Check if reset has been done this month
  Future<bool> _shouldResetThisMonth() async {
    try {
      print('Fetching reset tracker document...');
      final doc = await _firestore
          .collection('reset_tracker')
          .doc(currentUserId)
          .get();

      print('Reset tracker exists: ${doc.exists}');

      if (!doc.exists) {
        print('No reset record found - first time reset needed');
        return true;
      }

      final data = doc.data();
      print('Reset tracker data: $data');

      final lastResetStr = data?['lastResetDate'] as String?;

      if (lastResetStr == null) {
        print('Invalid reset record - reset needed');
        return true;
      }

      final lastReset = DateTime.parse(lastResetStr);
      final now = DateTime.now();

      // Check if we're in a different month/year
      final isDifferentMonth =
          lastReset.year != now.year || lastReset.month != now.month;

      print(
        'Last reset: ${lastReset.year}-${lastReset.month}-${lastReset.day}',
      );
      print('Current date: ${now.year}-${now.month}-${now.day}');
      print('Is different month? $isDifferentMonth');

      return isDifferentMonth;
    } catch (e, stackTrace) {
      print('Error checking reset status: $e');
      print('Stack trace: $stackTrace');
      return true; // If error, assume reset is needed
    }
  }

  /// Perform the actual monthly reset - IMPROVED VERSION
  Future<void> _performMonthlyReset() async {
    try {
      // Archive previous month's data (optional but recommended)
      await _archivePreviousMonthData();

      // Reset budgets instead of deleting them
      await _resetMonthlyBudgets();

      // Disable alert rules instead of deleting them
      await _disableAlertRules();

      // Reset savings tracking for non-piggybank savings goals
      await _resetMonthlySavingsTracking();

      // Send notification to user about reset
      await NotificationService.sendReminderNotification(
        title: '📅 New Month Started',
        body:
            'Your budgets have been reset. Review and enable your alert rules for this month.',
      );

      print('Monthly reset operations completed');
    } catch (e) {
      print('Error performing monthly reset: $e');
      rethrow;
    }
  }

  /// Archive previous month's data for historical tracking
  Future<void> _archivePreviousMonthData() async {
    try {
      print('📦 Archiving previous month data...');

      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final archiveId =
          '${lastMonth.year}_${lastMonth.month.toString().padLeft(2, '0')}';

      // Get current month's budget performance
      final budgetsSnapshot = await _firestore
          .collection('budgets')
          .doc(currentUserId)
          .collection('userBudgets')
          .where('period', isEqualTo: 'monthly')
          .get();

      if (budgetsSnapshot.docs.isNotEmpty) {
        Map<String, dynamic> archiveData = {
          'userId': currentUserId,
          'month': lastMonth.month,
          'year': lastMonth.year,
          'archivedAt': DateTime.now().toIso8601String(),
          'budgets': [],
        };

        for (var doc in budgetsSnapshot.docs) {
          final budget = BudgetModel.fromMap(doc.data());
          archiveData['budgets'].add({
            'category': budget.category,
            'budgetAmount': budget.amount,
            'actualSpent': budget.spent,
            'percentUsed': budget.percentSpent,
          });
        }

        // Save archive
        await _firestore
            .collection('budget_archives')
            .doc(currentUserId)
            .collection('monthly_archives')
            .doc(archiveId)
            .set(archiveData);

        print('✅ Archived ${budgetsSnapshot.docs.length} budgets');
      }
    } catch (e) {
      print('⚠️ Error archiving data (non-critical): $e');
      // Don't throw - archiving is optional
    }
  }

  /// Reset all monthly budgets - IMPROVED VERSION
  Future<void> _resetMonthlyBudgets() async {
    try {
      print('🔄 Starting to reset monthly budgets...');
      print('Querying budgets for user: $currentUserId');

      final budgetsSnapshot = await _firestore
          .collection('budgets')
          .doc(currentUserId)
          .collection('userBudgets')
          .where('period', isEqualTo: 'monthly')
          .get();

      print('Found ${budgetsSnapshot.docs.length} monthly budgets');

      if (budgetsSnapshot.docs.isEmpty) {
        print('No monthly budgets found to reset');
        return;
      }

      WriteBatch batch = _firestore.batch();
      int resetCount = 0;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      for (var doc in budgetsSnapshot.docs) {
        final budget = BudgetModel.fromMap(doc.data());

        // Reset budget: keep configuration but reset spending
        final resetBudget = budget.copyWith(
          spent: 0.0, // Reset spending to 0
          startDate: monthStart,
          endDate: monthEnd,
        );

        print(
          'Resetting budget: ${budget.category} (was ${budget.spent}/${budget.amount})',
        );
        batch.update(doc.reference, resetBudget.toMap());
        resetCount++;
      }

      await batch.commit();
      print('✅ Reset $resetCount monthly budgets successfully');
    } catch (e, stackTrace) {
      print('❌ Error resetting monthly budgets: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Disable all alert rules - IMPROVED VERSION
  Future<void> _disableAlertRules() async {
    try {
      print('🔕 Starting to disable alert rules...');
      print('Querying rules for user: $currentUserId');

      final rulesSnapshot = await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .where('type', isEqualTo: 'alert')
          .get();

      print('Found ${rulesSnapshot.docs.length} alert rules');

      if (rulesSnapshot.docs.isEmpty) {
        print('No alert rules found to disable');
        return;
      }

      WriteBatch batch = _firestore.batch();
      int disableCount = 0;

      for (var doc in rulesSnapshot.docs) {
        final rule = RuleModel.fromMap(doc.data());

        // Check if we should auto-enable (based on user preference)
        bool shouldAutoEnable = await _shouldAutoEnableAlert(rule);

        // Update rule: disable by default or auto-enable based on preference
        final updates = {
          'isActive': shouldAutoEnable,
          'lastTriggered': null, // Clear last triggered
          'monthlyResetDate': DateTime.now().toIso8601String(),
        };

        print(
          '${shouldAutoEnable ? "Auto-enabling" : "Disabling"} alert: ${rule.name}',
        );
        batch.update(doc.reference, updates);
        disableCount++;
      }

      await batch.commit();
      print('✅ Processed $disableCount alert rules');
    } catch (e, stackTrace) {
      print('❌ Error disabling alert rules: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if an alert should be auto-enabled based on user preferences
  Future<bool> _shouldAutoEnableAlert(RuleModel rule) async {
    // Check if rule has auto-enable flag in metadata
    final autoEnable = rule.conditions['autoEnableMonthly'] ?? false;

    // You can also check user-level preferences here
    final userDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data();
      final globalAutoEnable = userData?['autoEnableAlertsMonthly'] ?? false;
      return autoEnable || globalAutoEnable;
    }

    return autoEnable;
  }

  /// Reset monthly savings tracking (optional)
  Future<void> _resetMonthlySavingsTracking() async {
    try {
      print('🎯 Resetting monthly savings tracking...');

      final savingsRulesSnapshot = await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .where('type', isEqualTo: 'savings')
          .get();

      if (savingsRulesSnapshot.docs.isEmpty) {
        print('No savings rules found');
        return;
      }

      WriteBatch batch = _firestore.batch();
      int resetCount = 0;

      for (var doc in savingsRulesSnapshot.docs) {
        final rule = RuleModel.fromMap(doc.data());

        // Only reset non-piggybank monthly savings goals
        if (rule.isPiggyBank != true &&
            rule.conditions['resetMonthly'] == true) {
          batch.update(doc.reference, {
            'currentAmount': 0.0,
            'monthlyResetDate': DateTime.now().toIso8601String(),
          });

          print('Reset savings goal: ${rule.goalName}');
          resetCount++;
        }
      }

      if (resetCount > 0) {
        await batch.commit();
        print('✅ Reset $resetCount monthly savings goals');
      }
    } catch (e) {
      print('⚠️ Error resetting savings tracking (non-critical): $e');
      // Don't throw - this is optional
    }
  }

  /// Save the reset timestamp
  Future<void> _saveResetTimestamp() async {
    try {
      await _firestore.collection('reset_tracker').doc(currentUserId).set({
        'lastResetDate': DateTime.now().toIso8601String(),
        'lastResetMonth': DateTime.now().month,
        'lastResetYear': DateTime.now().year,
        'resetType': 'soft', // Indicates new reset method
      }, SetOptions(merge: true));

      print('Reset timestamp saved');
    } catch (e) {
      print('Error saving reset timestamp: $e');
    }
  }

  /// Manually enable all alert rules (for user action)
  Future<void> enableAllAlertRules() async {
    try {
      print('✅ Enabling all alert rules...');

      final rulesSnapshot = await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .where('type', isEqualTo: 'alert')
          .get();

      WriteBatch batch = _firestore.batch();

      for (var doc in rulesSnapshot.docs) {
        batch.update(doc.reference, {'isActive': true});
      }

      await batch.commit();
      print('Enabled ${rulesSnapshot.docs.length} alert rules');
    } catch (e) {
      print('Error enabling alert rules: $e');
      rethrow;
    }
  }

  /// Get archived budget data for analytics
  Future<List<Map<String, dynamic>>> getArchivedBudgets({
    int? year,
    int? month,
  }) async {
    try {
      Query query = _firestore
          .collection('budget_archives')
          .doc(currentUserId)
          .collection('monthly_archives');

      if (year != null) {
        query = query.where('year', isEqualTo: year);
      }
      if (month != null) {
        query = query.where('month', isEqualTo: month);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting archived budgets: $e');
      return [];
    }
  }

  /// Get monthly spending trends from archives
  Future<Map<String, List<double>>> getSpendingTrends({
    required int monthsBack,
  }) async {
    try {
      Map<String, List<double>> trends = {};
      final now = DateTime.now();

      for (int i = 0; i < monthsBack; i++) {
        final targetDate = DateTime(now.year, now.month - i, 1);
        final archiveId =
            '${targetDate.year}_${targetDate.month.toString().padLeft(2, '0')}';

        final doc = await _firestore
            .collection('budget_archives')
            .doc(currentUserId)
            .collection('monthly_archives')
            .doc(archiveId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final budgets = data['budgets'] as List;

          for (var budget in budgets) {
            final category = budget['category'] as String;
            final spent = (budget['actualSpent'] as num).toDouble();

            trends[category] ??= [];
            trends[category]!.insert(
              0,
              spent,
            ); // Insert at beginning for chronological order
          }
        }
      }

      return trends;
    } catch (e) {
      print('Error getting spending trends: $e');
      return {};
    }
  }

  /// Reset weekly budgets (call this weekly) - IMPROVED VERSION
  Future<void> resetWeeklyBudgets() async {
    try {
      print('Resetting weekly budgets...');

      final budgetsSnapshot = await _firestore
          .collection('budgets')
          .doc(currentUserId)
          .collection('userBudgets')
          .where('period', isEqualTo: 'weekly')
          .get();

      if (budgetsSnapshot.docs.isEmpty) {
        print('No weekly budgets found to reset');
        return;
      }

      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );

      WriteBatch batch = _firestore.batch();
      int resetCount = 0;

      for (var doc in budgetsSnapshot.docs) {
        final budget = BudgetModel.fromMap(doc.data());

        // Only reset if week has ended
        if (now.isAfter(budget.endDate)) {
          // Archive weekly data before reset (optional)
          await _archiveWeeklyBudget(budget);

          final resetBudget = budget.copyWith(
            spent: 0.0,
            startDate: weekStart,
            endDate: weekEnd,
          );

          batch.update(doc.reference, resetBudget.toMap());
          resetCount++;
        }
      }

      if (resetCount > 0) {
        await batch.commit();
        print('Reset $resetCount weekly budgets');
      }
    } catch (e) {
      print('Error resetting weekly budgets: $e');
    }
  }

  /// Archive weekly budget data
  Future<void> _archiveWeeklyBudget(BudgetModel budget) async {
    try {
      final weekId =
          '${budget.startDate.year}_W${_getWeekNumber(budget.startDate)}';

      await _firestore
          .collection('budget_archives')
          .doc(currentUserId)
          .collection('weekly_archives')
          .doc(weekId)
          .set({
            'category': budget.category,
            'budgetAmount': budget.amount,
            'actualSpent': budget.spent,
            'percentUsed': budget.percentSpent,
            'startDate': budget.startDate.toIso8601String(),
            'endDate': budget.endDate.toIso8601String(),
            'archivedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error archiving weekly budget: $e');
    }
  }

  /// Get week number for a date
  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  // ========== AUTHENTICATION ==========

  Future<User?> signUp(
    String email,
    String password,
    String fullName,
    String username,
    String incomeType,
    double monthlyIncome,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        UserModel userModel = UserModel(
          uid: user.uid,
          email: email,
          fullName: fullName,
          username: username,
          incomeType: incomeType,
          monthlyIncome: monthlyIncome,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toMap());

        // await _initializeDefaultBudgets(user.uid, incomeType);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('This email is already registered');
        case 'weak-password':
          throw Exception('Password is too weak (minimum 6 characters)');
        case 'invalid-email':
          throw Exception('Invalid email address');
        case 'operation-not-allowed':
          throw Exception('Email/password accounts are not enabled');
        default:
          throw Exception('Sign up failed: ${e.message}');
      }
    } on FirebaseException catch (e) {
      print('Firebase Error: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception(
          'Permission denied. Please check your account settings.',
        );
      }
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      print('Error signing up: $e');
      throw Exception('An unexpected error occurred during sign up');
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found with this email');
        case 'wrong-password':
          throw Exception('Incorrect password');
        case 'invalid-email':
          throw Exception('Invalid email address');
        case 'user-disabled':
          throw Exception('This account has been disabled');
        case 'invalid-credential':
          throw Exception('Invalid email or password');
        case 'too-many-requests':
          throw Exception('Too many failed attempts. Please try again later');
        default:
          throw Exception('Login failed: ${e.message}');
      }
    } catch (e) {
      print('Error signing in: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred during login');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ========== USER PROFILE ==========

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      // Get old user profile to check if income type changed
      final oldUser = await getUserProfile(user.uid);
      final incomeTypeChanged = oldUser?.incomeType != user.incomeType;

      // Update profile
      await _firestore.collection('users').doc(user.uid).update(user.toMap());
      // If income type changed, recalculate all budgets
      if (incomeTypeChanged) {
        print(
          'Income type changed from ${oldUser?.incomeType} to ${user.incomeType}',
        );
        await recalculateBudgetsForIncomeType(user.incomeType);
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // ========== TRANSACTIONS ==========

  Future<String> addTransaction(TransactionModel transaction) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('transactions')
          .doc(currentUserId)
          .collection('userTransactions')
          .add(transaction.toMap());

      String id = docRef.id;
      await docRef.update({'id': id});

      // Update budget spent amount if expense (use actual expense amount)
      if (transaction.type == 'expense') {
        await _updateBudgetSpent(
          transaction.category,
          transaction.actualExpenseAmount,
        );
      }

      // Update savings goal progress if has savings allocation
      if (transaction.hasSavingsAllocation &&
          transaction.savingsGoalId != null) {
        await updateSavingsProgress(
          transaction.savingsGoalId!,
          transaction.savingsAllocation!,
        );
      }

      // Check and apply allocation rules (for income)
      if (transaction.type == 'income') {
        await _applyAllocationRules(transaction);
      }

      // Check alerts immediately after expense transaction - WITH ERROR HANDLING
      if (transaction.type == 'expense' && currentUserId != null) {
        try {
          print('Transaction saved, checking alerts...');
          final alertService = AlertService(currentUserId!);
          await alertService.checkAlertForTransaction(transaction);
          print('Alert check completed');
        } catch (e) {
          print('ERROR during alert check: $e');
          print('Stack trace: ${StackTrace.current}');
          // Don't throw - allow transaction to complete even if alert fails
        }
      }

      return id;
    } catch (e) {
      print('Error adding transaction: $e');
      return '';
    }
  }

  Stream<List<TransactionModel>> getTransactions() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('transactions')
        .doc(currentUserId)
        .collection('userTransactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TransactionModel.fromMap(doc.data()))
              .toList();
        });
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      final doc = await _firestore
          .collection('transactions')
          .doc(currentUserId)
          .collection('userTransactions')
          .doc(transactionId)
          .get();

      if (doc.exists) {
        final transaction = TransactionModel.fromMap(doc.data()!);

        if (transaction.type == 'expense') {
          // Reverse budget spent with actual expense amount
          await _updateBudgetSpent(
            transaction.category,
            -transaction.actualExpenseAmount,
          );

          // Reverse savings progress if has allocation
          if (transaction.hasSavingsAllocation &&
              transaction.savingsGoalId != null) {
            await updateSavingsProgress(
              transaction.savingsGoalId!,
              -transaction.savingsAllocation!,
            );
          }
        }

        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting transaction: $e');
      rethrow;
    }
  }

  /// Apply allocation rules for income transaction
  Future<void> _applyAllocationRules(TransactionModel transaction) async {
    if (currentUserId == null) return;

    try {
      final user = await getUserProfile(currentUserId!);
      if (user != null) {
        final allocationService = IncomeAllocationService(currentUserId!);
        await allocationService.processIncomeTransaction(transaction, user);
      }
    } catch (e) {
      print('Error applying allocation rules: $e');
    }
  }

  // ========== BUDGETS ==========

  Future<void> addBudget(BudgetModel budget) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('budgets')
          .doc(currentUserId)
          .collection('userBudgets')
          .add(budget.toMap());

      String id = docRef.id;
      await docRef.update({'id': id});
    } catch (e) {
      print('Error adding budget: $e');
    }
  }

  Stream<List<BudgetModel>> getBudgets() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('budgets')
        .doc(currentUserId)
        .collection('userBudgets')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BudgetModel.fromMap(doc.data()))
              .toList();
        });
  }

  Future<void> updateBudget(BudgetModel budget) async {
    await _firestore
        .collection('budgets')
        .doc(currentUserId)
        .collection('userBudgets')
        .doc(budget.id)
        .update(budget.toMap());
  }

  Future<void> deleteBudget(String budgetId) async {
    try {
      await _firestore
          .collection('budgets')
          .doc(currentUserId)
          .collection('userBudgets')
          .doc(budgetId)
          .delete();
    } catch (e) {
      print('Error deleting budget: $e');
      rethrow;
    }
  }

  // ========== BUDGET-ALLOCATION SYNC ==========

  Future<void> _createBudgetFromAllocation(
    RuleModel rule,
    UserModel user,
  ) async {
    try {
      final category = rule.conditions['category'] as String?;
      final amountType = rule.conditions['amountType'] as String?;
      final amountValue =
          (rule.conditions['amountValue'] as num?)?.toDouble() ?? 0.0;

      if (category == null || amountValue <= 0) return;

      // Calculate budget amount
      double budgetAmount = amountValue;
      if (amountType == 'percentage') {
        budgetAmount = (user.monthlyIncome ?? 0) * (amountValue / 100);
      }

      String period = 'monthly';
      DateTime now = DateTime.now();
      DateTime endDate = DateTime(now.year, now.month + 1, 0);

      // Convert to weekly for variable/hybrid earners
      if (user.incomeType == 'variable' || user.incomeType == 'hybrid') {
        budgetAmount = budgetAmount / 4;
        period = 'weekly';
        endDate = now.add(const Duration(days: 7));
      }

      // Check if budget exists
      final existingBudgets = await _firestore
          .collection('budgets')
          .doc(currentUserId)
          .collection('userBudgets')
          .where('category', isEqualTo: category)
          .limit(1)
          .get();

      if (existingBudgets.docs.isNotEmpty) {
        // Update existing budget
        final doc = existingBudgets.docs.first;
        final existingBudget = BudgetModel.fromMap(doc.data());

        final updatedBudget = existingBudget.copyWith(
          amount: budgetAmount,
          period: period,
          endDate: endDate,
          linkedAlertRuleId: rule.id,
          isAutoCreated: true,
        );

        await updateBudget(updatedBudget);
      } else {
        // Create new budget
        final newBudget = BudgetModel(
          id: '',
          userId: currentUserId!,
          category: category,
          amount: budgetAmount,
          spent: 0,
          period: period,
          startDate: now,
          endDate: endDate,
          linkedAlertRuleId: rule.id,
          isAutoCreated: true,
        );

        await addBudget(newBudget);
      }
    } catch (e) {
      print('Error creating budget from allocation: $e');
    }
  }

  /// Reset budget if it's an allocation rule
  Future<void> _resetBudgetFromAllocation(String allocationRuleId) async {
    try {
      final budgets = await _firestore
          .collection('budgets')
          .doc(currentUserId)
          .collection('userBudgets')
          .where('linkedAlertRuleId', isEqualTo: allocationRuleId)
          .get();

      for (var doc in budgets.docs) {
        final budget = BudgetModel.fromMap(doc.data());

        final resetBudget = budget.copyWith(
          amount: 0,
          linkedAlertRuleId: null,
          isAutoCreated: false,
        );

        await updateBudget(resetBudget);
      }
    } catch (e) {
      print('Error resetting budget from allocation: $e');
    }
  }

  Future<void> recalculateBudgetsForIncomeType(String incomeType) async {
    try {
      final budgetsSnapshot = await _firestore
          .collection('budgets')
          .doc(currentUserId)
          .collection('userBudgets')
          .get();

      WriteBatch batch = _firestore.batch();
      DateTime now = DateTime.now();

      for (var doc in budgetsSnapshot.docs) {
        final budget = BudgetModel.fromMap(doc.data());
        String newPeriod;
        DateTime newEndDate;
        double newAmount = budget.amount;

        if (incomeType == 'variable' || incomeType == 'hybrid') {
          // Convert to weekly
          newPeriod = 'weekly';
          newEndDate = now.add(const Duration(days: 7));

          // If converting from monthly, divide by 4
          if (budget.period == 'monthly') {
            newAmount = budget.amount / 4;
          }
        } else {
          // Convert to monthly
          newPeriod = 'monthly';
          newEndDate = DateTime(now.year, now.month + 1, 0);

          // If converting from weekly, multiply by 4
          if (budget.period == 'weekly') {
            newAmount = budget.amount * 4;
          }
        }

        final updatedBudget = budget.copyWith(
          period: newPeriod,
          amount: newAmount,
          endDate: newEndDate,
        );

        batch.update(doc.reference, updatedBudget.toMap());
      }

      await batch.commit();
      print(
        'Recalculated ${budgetsSnapshot.docs.length} budgets for $incomeType earner',
      );
    } catch (e) {
      print('Error recalculating budgets: $e');
    }
  }

  // ========== RULES ==========

  Future<void> addRule(RuleModel rule) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .add(rule.toMap());

      String id = docRef.id;
      await docRef.update({'id': id});

      // If it's an alert rule, create a budget for it
      if (rule.type == 'allocation') {
        final user = await getUserProfile(currentUserId!);
        if (user != null) {
          final updatedRule = rule.copyWith(id: id);
          await _createBudgetFromAllocation(updatedRule, user);
        }
      }
    } catch (e) {
      print('Error adding rule: $e');
      rethrow;
    }
  }

  Stream<List<RuleModel>> getRules({String? type}) {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    Query query = _firestore
        .collection('rules')
        .doc(currentUserId)
        .collection('userRules');

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RuleModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> updateRule(RuleModel rule) async {
    try {
      await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .doc(rule.id)
          .update(rule.toMap());

      // If it's an alert rule, update its linked budget
      if (rule.type == 'allocation') {
        final user = await getUserProfile(currentUserId!);
        if (user != null) {
          await _createBudgetFromAllocation(rule, user);
        }
      }
    } catch (e) {
      print('Error updating rule: $e');
      rethrow;
    }
  }

  Future<void> deleteRule(String ruleId) async {
    try {
      // Get the rule to check its type
      final doc = await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .doc(ruleId)
          .get();

      if (doc.exists) {
        final rule = RuleModel.fromMap(doc.data()!);

        // If it's an alert rule, reset its linked budget
        if (rule.type == 'allocation') {
          await _resetBudgetFromAllocation(ruleId);
        }

        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting rule: $e');
      rethrow;
    }
  }

  Future<void> toggleRuleStatus(String ruleId, bool isActive) async {
    await _firestore
        .collection('rules')
        .doc(currentUserId)
        .collection('userRules')
        .doc(ruleId)
        .update({'isActive': isActive});
  }

  // ========== SAVINGS GOALS ==========

  Future<void> updateSavingsProgress(String ruleId, double amount) async {
    try {
      final doc = await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .doc(ruleId)
          .get();

      if (doc.exists) {
        final rule = RuleModel.fromMap(doc.data()!);
        final newAmount = (rule.currentAmount ?? 0) + amount;

        await _firestore
            .collection('rules')
            .doc(currentUserId)
            .collection('userRules')
            .doc(ruleId)
            .update({'currentAmount': newAmount});

        // Check if we should notify about progress
        final alertService = AlertService(currentUserId!);
        await alertService.checkSavingsGoalProgress(
          rule.copyWith(currentAmount: newAmount),
        );
      }
    } catch (e) {
      print('Error updating savings progress: $e');
    }
  }

  // ========== ALERT PROCESSING ==========

  Future<void> processAllocationWithNotification({
    required RuleModel rule,
    required double incomeAmount,
    required double allocatedAmount,
  }) async {
    // Update rule lastTriggered
    await updateRule(rule.copyWith(lastTriggered: DateTime.now()));

    // Send notification
    final percentage = rule.actions['allocateToSavings'] ?? 0.0;
    await NotificationService.sendAllocationNotification(
      ruleName: rule.name,
      amount: allocatedAmount,
      percentage: percentage.toDouble(),
    );
  }

  Future<void> scheduleDailyAlertCheck() async {
    await NotificationService.sendReminderNotification(
      title: 'Budget Check',
      body: 'Review your spending and budget progress for today',
    );
  }

  // ========== DASHBOARD STATISTICS ==========

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      if (currentUserId == null) {
        return {
          'totalIncome': 0.0,
          'totalExpenses': 0.0,
          'totalSavings': 0.0,
          'netAmount': 0.0,
          'weeklyIncome': 0.0,
          'weeklyExpenses': 0.0,
          'salaryIncome': 0.0,
          'gigIncome': 0.0,
        };
      }

      double totalIncome = 0;
      double totalExpenses = 0;
      double totalSavings = 0;
      double weeklyIncome = 0;
      double weeklyExpenses = 0;
      double salaryIncome = 0;
      double gigIncome = 0;

      DateTime now = DateTime.now();
      DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));

      QuerySnapshot transactionSnapshot = await _firestore
          .collection('transactions')
          .doc(currentUserId)
          .collection('userTransactions')
          .get();

      for (var doc in transactionSnapshot.docs) {
        TransactionModel transaction = TransactionModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );

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
          // Add actual expense amount (excluding savings)
          totalExpenses += transaction.actualExpenseAmount;

          // Track total savings from allocations
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
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {
        'totalIncome': 0.0,
        'totalExpenses': 0.0,
        'totalSavings': 0.0,
        'netAmount': 0.0,
        'weeklyIncome': 0.0,
        'weeklyExpenses': 0.0,
        'salaryIncome': 0.0,
        'gigIncome': 0.0,
      };
    }
  }

  // ========== PRIVATE HELPER METHODS ==========

  Future<void> _updateBudgetSpent(String category, double amount) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('budgets')
          .doc(currentUserId)
          .collection('userBudgets')
          .where('category', isEqualTo: category)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        DocumentSnapshot doc = snapshot.docs.first;
        BudgetModel budget = BudgetModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
        budget = budget.copyWith(spent: budget.spent + amount);
        await updateBudget(budget);
      }
    } catch (e) {
      print('Error updating budget spent: $e');
    }
  }

  /// Process income transaction with auto-allocation for variable earners
  Future<void> processIncomeWithAllocation(
    TransactionModel transaction,
    UserModel user,
  ) async {
    if (user.incomeType != 'variable' || transaction.type != 'income') {
      return;
    }

    try {
      print('Processing income with allocation for variable earner');

      // Initialize allocation service
      final allocationService = IncomeAllocationService(user.uid);

      // Process allocations
      final allocations = await allocationService.processIncomeTransaction(
        transaction,
        user,
      );

      // Store allocation details with transaction
      if (allocations.isNotEmpty) {
        await _firestore
            .collection('transactions')
            .doc(user.uid)
            .collection('userTransactions')
            .doc(transaction.id)
            .update({
              'allocations': allocations,
              'totalAllocated': allocations.values.reduce((a, b) => a + b),
              'processedAt': DateTime.now().toIso8601String(),
            });
      }

      print('Income allocation processing completed');
    } catch (e) {
      print('Error processing income allocation: $e');
      rethrow;
    }
  }

  /// Get variable earner weekly stats
  Future<Map<String, dynamic>> getVariableEarnerWeeklyStats() async {
    final userId = currentUserId;
    if (userId == null) return {};

    final now = DateTime.now();
    final weekStart = _getWeekStart(now);

    // Get transactions for current week
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .doc(userId)
        .collection('userTransactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get();

    double weeklyIncome = 0;
    double weeklyExpenses = 0;
    Map<String, double> incomeBySource = {};
    Map<String, double> expenseByCategory = {};
    double totalAllocated = 0;

    for (var doc in transactionsSnapshot.docs) {
      final transaction = TransactionModel.fromMap(doc.data());

      if (transaction.type == 'income') {
        weeklyIncome += transaction.amount;
        incomeBySource[transaction.category] =
            (incomeBySource[transaction.category] ?? 0) + transaction.amount;

        // Check for allocations
        final allocations = doc.data()['allocations'] as Map<String, dynamic>?;
        if (allocations != null) {
          totalAllocated += (doc.data()['totalAllocated'] ?? 0).toDouble();
        }
      } else {
        weeklyExpenses += transaction.actualExpenseAmount;
        expenseByCategory[transaction.category] =
            (expenseByCategory[transaction.category] ?? 0) +
            transaction.actualExpenseAmount;
      }
    }

    // Get weekly budgets
    final budgetsSnapshot = await _firestore
        .collection('budgets')
        .doc(userId)
        .collection('userBudgets')
        .where('period', isEqualTo: 'weekly')
        .where('startDate', isGreaterThanOrEqualTo: weekStart.toIso8601String())
        .get();

    List<Map<String, dynamic>> weeklyBudgets = [];
    double totalBudgetAmount = 0;
    double totalBudgetSpent = 0;

    for (var doc in budgetsSnapshot.docs) {
      final budget = BudgetModel.fromMap(doc.data());
      totalBudgetAmount += budget.amount;
      totalBudgetSpent += budget.spent;

      // Update spent amount from actual expenses
      final actualSpent = expenseByCategory[budget.category] ?? 0;

      weeklyBudgets.add({
        'budget': budget,
        'actualSpent': actualSpent,
        'percentUsed': budget.amount > 0
            ? (actualSpent / budget.amount * 100)
            : 0,
      });
    }

    // Calculate income volatility (compare with last week)
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = weekStart.subtract(const Duration(seconds: 1));

    final lastWeekIncomeSnapshot = await _firestore
        .collection('transactions')
        .doc(userId)
        .collection('userTransactions')
        .where('type', isEqualTo: 'income')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(lastWeekStart),
        )
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastWeekEnd))
        .get();

    double lastWeekIncome = 0;
    for (var doc in lastWeekIncomeSnapshot.docs) {
      final transaction = TransactionModel.fromMap(doc.data());
      lastWeekIncome += transaction.amount;
    }

    double incomeChangePercent = 0;
    if (lastWeekIncome > 0) {
      incomeChangePercent =
          ((weeklyIncome - lastWeekIncome) / lastWeekIncome * 100);
    }

    // Calculate runway (how many weeks of expenses can be covered)
    final totalBalance = await _calculateTotalBalance(userId);
    final weeklyBurnRate = weeklyExpenses > 0 ? weeklyExpenses : 1;
    final runwayWeeks = (totalBalance / weeklyBurnRate).round();

    return {
      'weeklyIncome': weeklyIncome,
      'weeklyExpenses': weeklyExpenses,
      'netWeekly': weeklyIncome - weeklyExpenses,
      'incomeBySource': incomeBySource,
      'expenseByCategory': expenseByCategory,
      'totalAllocated': totalAllocated,
      'unallocatedIncome': weeklyIncome - totalAllocated,
      'weeklyBudgets': weeklyBudgets,
      'totalBudgetAmount': totalBudgetAmount,
      'totalBudgetSpent': totalBudgetSpent,
      'budgetUtilization': totalBudgetAmount > 0
          ? (totalBudgetSpent / totalBudgetAmount * 100)
          : 0,
      'lastWeekIncome': lastWeekIncome,
      'incomeChangePercent': incomeChangePercent,
      'incomeVolatility': incomeChangePercent.abs() > 25 ? 'HIGH' : 'STABLE',
      'totalBalance': totalBalance,
      'runwayWeeks': runwayWeeks,
      'runwayStatus': runwayWeeks > 4 ? 'HEALTHY' : 'CRITICAL',
      'weekStart': weekStart.toIso8601String(),
    };
  }

  /// Create income allocation rule
  Future<void> createIncomeAllocationRule({
    required String ruleName,
    required String incomeSource, // 'all', 'Gig Work', 'Gift', etc.
    required String allocationType, // 'percentage' or 'fixed'
    required double allocationValue,
    required String targetCategory,
    required int priority,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('No user logged in');

    final ruleId = _firestore
        .collection('rules')
        .doc(userId)
        .collection('userRules')
        .doc()
        .id;

    final rule = RuleModel(
      id: ruleId,
      userId: userId,
      name: ruleName,
      type: 'income_allocation',
      conditions: {
        'incomeSource': incomeSource,
        'allocationType': allocationType,
        'allocationValue': allocationValue,
      },
      actions: {
        'targetCategory': targetCategory,
        'createBudget': true,
        'createAlert': true,
      },
      priority: priority,
      isActive: true,
      createdAt: DateTime.now(),
      incomeSource: incomeSource,
      allocationType: allocationType,
      allocationValue: allocationValue,
      targetCategory: targetCategory,
      weeklyAllocatedAmount: 0,
      weekStartDate: _getWeekStart(DateTime.now()),
    );

    await _firestore
        .collection('rules')
        .doc(userId)
        .collection('userRules')
        .doc(ruleId)
        .set(rule.toMap());

    print('Created income allocation rule: $ruleName');

    // Retroactively apply this rule to existing weekly income
    try {
      final allocationService = IncomeAllocationService(userId);
      await allocationService.applyRuleToWeeklyIncome(rule);
    } catch (e) {
      print('Error applying rule retroactively: $e');
    }
  }

  /// Get all income allocation rules
  Stream<List<RuleModel>> getIncomeAllocationRules() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('rules')
        .doc(userId)
        .collection('userRules')
        .where('type', isEqualTo: 'income_allocation')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RuleModel.fromMap(doc.data()))
              .toList(),
        );
  }

  /// Update weekly budgets spent amounts
  Future<void> updateWeeklyBudgetSpent(String category, double amount) async {
    final userId = currentUserId;
    if (userId == null) return;

    final weekStart = _getWeekStart(DateTime.now());

    // Find the weekly budget for this category
    final budgetQuery = await _firestore
        .collection('budgets')
        .doc(userId)
        .collection('userBudgets')
        .where('category', isEqualTo: category)
        .where('period', isEqualTo: 'weekly')
        .where('startDate', isGreaterThanOrEqualTo: weekStart.toIso8601String())
        .limit(1)
        .get();

    if (budgetQuery.docs.isNotEmpty) {
      final budgetDoc = budgetQuery.docs.first;
      final currentBudget = BudgetModel.fromMap(budgetDoc.data());

      await _firestore
          .collection('budgets')
          .doc(userId)
          .collection('userBudgets')
          .doc(budgetDoc.id)
          .update({'spent': currentBudget.spent + amount});

      print('Updated weekly budget spent for $category: +$amount');
    }
  }

  /// Check and perform weekly reset for variable earners
  Future<void> checkAndPerformWeeklyReset() async {
    final userId = currentUserId;
    if (userId == null) return;

    // Get user to check if variable earner
    final user = await getUserProfile(userId);
    if (user == null || user.incomeType != 'variable') {
      return;
    }

    final now = DateTime.now();

    // Only reset on Mondays
    if (now.weekday != DateTime.monday) {
      return;
    }

    // Check last reset
    final lastResetDoc = await _firestore
        .collection('weekly_resets')
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

    print('Performing weekly reset for variable earner...');

    // Reset allocation tracking
    final allocationService = IncomeAllocationService(userId);
    await allocationService.checkAndResetWeeklyAllocations();

    // Update last reset timestamp
    await _firestore.collection('weekly_resets').doc(userId).set({
      'lastReset': now.toIso8601String(),
      'weekStart': _getWeekStart(now).toIso8601String(),
    });

    // Send notification
    await NotificationService.sendReminderNotification(
      title: '📅 New Week Started',
      body:
          'Your weekly budgets have been reset. Add income to auto-allocate budgets!',
    );

    print('Weekly reset completed');
  }

  /// Calculate total balance (for runway calculation) - helper method
  Future<double> _calculateTotalBalance(String userId) async {
    // Get all transactions
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .doc(userId)
        .collection('userTransactions')
        .get();

    double totalIncome = 0;
    double totalExpenses = 0;

    for (var doc in transactionsSnapshot.docs) {
      final transaction = TransactionModel.fromMap(doc.data());
      if (transaction.type == 'income') {
        totalIncome += transaction.amount;
      } else {
        totalExpenses += transaction.actualExpenseAmount;
      }
    }

    return totalIncome - totalExpenses;
  }

  /// Get week start (Monday) - helper method
  DateTime _getWeekStart(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }
}
