import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/rule_model.dart';
import 'alert_service.dart';
import 'notification_service.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  // ========== AUTHENTICATION ==========

  Future<User?> signUp(String email, String password, String fullName,
      String username, String incomeType, double monthlyIncome) async {
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

        await _initializeDefaultBudgets(user.uid, incomeType);
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
        throw Exception('Permission denied. Please check your account settings.');
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
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
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
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update(user.toMap());
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
        await _updateBudgetSpent(transaction.category, transaction.actualExpenseAmount);
      }

      // Update savings goal progress if has savings allocation
      if (transaction.hasSavingsAllocation && transaction.savingsGoalId != null) {
        await updateSavingsProgress(transaction.savingsGoalId!, transaction.savingsAllocation!);
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
          await _updateBudgetSpent(transaction.category, -transaction.actualExpenseAmount);

          // Reverse savings progress if has allocation
          if (transaction.hasSavingsAllocation && transaction.savingsGoalId != null) {
            await updateSavingsProgress(transaction.savingsGoalId!, -transaction.savingsAllocation!);
          }
        }

        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting transaction: $e');
      rethrow;
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

      // Initialize progress tracking if it's a savings goal
      if (rule.type == 'savings' && rule.isPiggyBank != true && currentUserId != null) {
        await _firestore.collection('progress_milestones').doc(id).set({
          'lastMilestone': 0.0,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error adding rule: $e');
    }
  }

  Stream<List<RuleModel>> getRules() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('rules')
        .doc(currentUserId)
        .collection('userRules')
        .orderBy('priority', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RuleModel.fromMap(doc.data()))
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

      // Check if progress milestone reached for savings goals
      if (rule.type == 'savings' && rule.isPiggyBank != true && currentUserId != null) {
        final alertService = AlertService(currentUserId!);
        await alertService.checkSavingsGoalProgress(rule);
      }
    } catch (e) {
      print('Error updating rule: $e');
      rethrow;
    }
  }

  Future<void> deleteRule(String ruleId) async {
    try {
      await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .doc(ruleId)
          .delete();
    } catch (e) {
      print('Error deleting rule: $e');
      rethrow;
    }
  }

  // ========== CATEGORY SPENDING & ALERTS ==========

  Stream<Map<String, double>> getCategorySpending(String userId) {
    return _firestore
        .collection('transactions')
        .doc(userId)
        .collection('userTransactions')
        .where('type', isEqualTo: 'expense')
        .snapshots()
        .map((snapshot) {
      final Map<String, double> categoryTotals = {};

      for (var doc in snapshot.docs) {
        final transaction = TransactionModel.fromMap(doc.data());
        final category = transaction.category;

        // Use actual expense amount (excluding savings allocation)
        categoryTotals[category] = (categoryTotals[category] ?? 0.0) + transaction.actualExpenseAmount;
      }

      return categoryTotals;
    });
  }

  Future<void> checkAllAlerts() async {
    if (currentUserId == null) {
      print('Cannot check alerts: No user logged in');
      return;
    }

    try {
      print('Checking all alerts for user: $currentUserId');
      final alertService = AlertService(currentUserId!);
      await alertService.checkAndTriggerAlerts();
      print('All alerts checked successfully');
    } catch (e) {
      print('ERROR checking all alerts: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<Map<String, dynamic>> getAlertSummary() async {
    if (currentUserId == null) {
      return {'totalAlerts': 0, 'triggeredAlerts': 0, 'categories': []};
    }

    try {
      // Get all active alert rules
      final rulesSnapshot = await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .where('type', isEqualTo: 'alert')
          .where('isActive', isEqualTo: true)
          .get();

      final alertService = AlertService(currentUserId!);
      final categorySpending = await alertService.getCurrentCategorySpending();

      int triggeredCount = 0;
      List<String> triggeredCategories = [];

      for (var doc in rulesSnapshot.docs) {
        final rule = RuleModel.fromMap(doc.data());
        final category = rule.conditions['category'] as String?;
        final threshold = (rule.conditions['threshold'] as num?)?.toDouble() ?? 0.0;

        if (category != null) {
          final spending = categorySpending[category] ?? 0.0;
          if (spending >= threshold) {
            triggeredCount++;
            if (!triggeredCategories.contains(category)) {
              triggeredCategories.add(category);
            }
          }
        }
      }

      return {
        'totalAlerts': rulesSnapshot.docs.length,
        'triggeredAlerts': triggeredCount,
        'categories': triggeredCategories,
      };
    } catch (e) {
      print('ERROR getting alert summary: $e');
      return {'totalAlerts': 0, 'triggeredAlerts': 0, 'categories': []};
    }
  }

  Future<List<Map<String, dynamic>>> getAlertHistory({int limit = 10}) async {
    if (currentUserId == null) return [];

    final snapshot = await _firestore
        .collection('rules')
        .doc(currentUserId)
        .collection('userRules')
        .where('type', isEqualTo: 'alert')
        .where('lastTriggered', isNull: false)
        .orderBy('lastTriggered', descending: true)
        .limit(limit)
        .get();

    List<Map<String, dynamic>> history = [];

    for (var doc in snapshot.docs) {
      final rule = RuleModel.fromMap(doc.data());
      if (rule.lastTriggered != null) {
        history.add({
          'rule': rule,
          'triggeredAt': rule.lastTriggered,
          'category': rule.conditions['category'],
          'threshold': rule.conditions['threshold'],
        });
      }
    }

    return history;
  }

  Future<void> dismissAlert(String ruleId, Duration duration) async {
    await _firestore.collection('alert_dismissals').doc(ruleId).set({
      'userId': currentUserId,
      'dismissedUntil': DateTime.now().add(duration).toIso8601String(),
    });
  }

  Future<bool> isAlertDismissed(String ruleId) async {
    final doc = await _firestore
        .collection('alert_dismissals')
        .doc(ruleId)
        .get();

    if (!doc.exists) return false;

    final dismissedUntil = doc.data()?['dismissedUntil'] as String?;
    if (dismissedUntil == null) return false;

    final dismissTime = DateTime.parse(dismissedUntil);
    return DateTime.now().isBefore(dismissTime);
  }

  Future<Map<String, dynamic>> getAlertStatistics() async {
    if (currentUserId == null) return {};

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final snapshot = await _firestore
        .collection('rules')
        .doc(currentUserId)
        .collection('userRules')
        .where('type', isEqualTo: 'alert')
        .get();

    int totalAlerts = snapshot.docs.length;
    int activeAlerts = 0;
    int triggeredInLast30Days = 0;
    Map<String, int> categoryBreakdown = {};

    for (var doc in snapshot.docs) {
      final rule = RuleModel.fromMap(doc.data());

      if (rule.isActive) activeAlerts++;

      if (rule.lastTriggered != null &&
          rule.lastTriggered!.isAfter(thirtyDaysAgo)) {
        triggeredInLast30Days++;
      }

      final category = rule.conditions['category'] as String?;
      if (category != null) {
        categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + 1;
      }
    }

    return {
      'totalAlerts': totalAlerts,
      'activeAlerts': activeAlerts,
      'triggeredInLast30Days': triggeredInLast30Days,
      'categoryBreakdown': categoryBreakdown,
    };
  }

  // ========== SAVINGS ==========

  Future<void> updateSavingsProgress(String ruleId, double amountToAdd) async {
    try {
      final ruleDoc = await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .doc(ruleId)
          .get();

      if (!ruleDoc.exists) return;

      final rule = RuleModel.fromMap(ruleDoc.data()!);
      final newAmount = (rule.currentAmount ?? 0.0) + amountToAdd;

      await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .doc(ruleId)
          .update({
        'currentAmount': newAmount,
      });
    } catch (e) {
      print('Error updating savings progress: $e');
      rethrow;
    }
  }

  Future<double> getTotalSavings(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .doc(userId)
          .collection('userTransactions')
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final transaction = TransactionModel.fromMap(doc.data());
        if (transaction.hasSavingsAllocation) {
          total += transaction.savingsAllocation!;
        }
      }

      return total;
    } catch (e) {
      print('Error getting total savings: $e');
      return 0.0;
    }
  }

  Future<Map<String, double>> getSavingsByGoal(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .doc(userId)
          .collection('userTransactions')
          .get();

      final Map<String, double> goalTotals = {};

      for (var doc in snapshot.docs) {
        final transaction = TransactionModel.fromMap(doc.data());
        if (transaction.hasSavingsAllocation && transaction.savingsGoalName != null) {
          final goalName = transaction.savingsGoalName!;
          goalTotals[goalName] = (goalTotals[goalName] ?? 0.0) + transaction.savingsAllocation!;
        }
      }

      return goalTotals;
    } catch (e) {
      print('Error getting savings by goal: $e');
      return {};
    }
  }

  // ========== NOTIFICATIONS & REMINDERS ==========

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
            doc.data() as Map<String, dynamic>);

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

  Future<void> _initializeDefaultBudgets(String uid, String incomeType) async {
    List<Map<String, dynamic>> defaultCategories = [
      {'name': 'Food', 'icon': '🍔', 'amount': 20000},
      {'name': 'Transport', 'icon': '🚗', 'amount': 15000},
      {'name': 'Data', 'icon': '💾', 'amount': 10000},
      {'name': 'Entertainment', 'icon': '🎬', 'amount': 10000},
      {'name': 'Utilities', 'icon': '💡', 'amount': 20000},
    ];

    String period = incomeType == 'variable' ? 'weekly' : 'monthly';
    DateTime now = DateTime.now();
    DateTime endDate = period == 'weekly'
        ? now.add(const Duration(days: 7))
        : DateTime(now.year, now.month + 1, 0);

    WriteBatch batch = _firestore.batch();

    for (var category in defaultCategories) {
      BudgetModel budget = BudgetModel(
        id: '',
        userId: uid,
        category: category['name'],
        amount: category['amount'].toDouble(),
        period: period,
        startDate: now,
        endDate: endDate,
      );

      DocumentReference docRef = _firestore
          .collection('budgets')
          .doc(uid)
          .collection('userBudgets')
          .doc();

      budget.id = docRef.id;
      batch.set(docRef, budget.toMap());
    }

    await batch.commit();
  }

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
        BudgetModel budget = BudgetModel.fromMap(doc.data() as Map<String, dynamic>);
        budget.spent += amount;
        await updateBudget(budget);
      }
    } catch (e) {
      print('Error updating budget spent: $e');
    }
  }

  Future<void> _applyAllocationRules(TransactionModel transaction) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .where('type', isEqualTo: 'allocation')
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .get();

      List<RuleModel> rules = snapshot.docs
          .map((doc) => RuleModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      for (RuleModel rule in rules) {
        final minAmount = rule.conditions['minAmount'] as num? ?? 0;

        if (transaction.amount >= minAmount) {
          final allocatePercent = rule.actions['allocateToSavings'] as num? ?? 0;
          final savingsAmount = transaction.amount * (allocatePercent / 100);

          // Create expense transaction with savings allocation
          TransactionModel allocationTransaction = TransactionModel(
            id: '',
            userId: currentUserId!,
            type: 'expense',
            category: 'Savings',
            amount: savingsAmount,
            description: 'Auto-allocated from ${transaction.description}',
            date: DateTime.now(),
            savingsAllocation: savingsAmount,
            savingsGoalId: rule.id,
            savingsGoalName: 'Auto-Allocation',
          );

          await addTransaction(allocationTransaction);

          await _firestore
              .collection('rules')
              .doc(currentUserId)
              .collection('userRules')
              .doc(rule.id)
              .update({'lastTriggered': DateTime.now().toIso8601String()});

          // Send notification
          await processAllocationWithNotification(
            rule: rule,
            incomeAmount: transaction.amount,
            allocatedAmount: savingsAmount,
          );
        }
      }
    } catch (e) {
      print('Error applying allocation rules: $e');
    }
  }
}