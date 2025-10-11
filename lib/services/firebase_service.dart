import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/rule_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// Get current user
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

// Authentication
  Future<User?> signUp(String email, String password, String fullName,
      String username, String incomeType) async {
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
      // Re-throw with user-friendly message
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
      // Provide specific error messages
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
        rethrow; // Re-throw our custom exceptions
      }
      throw Exception('An unexpected error occurred during login');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // User Profile
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

  // Transactions
  Future<String> addTransaction(TransactionModel transaction) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('transactions')
          .doc(currentUserId)
          .collection('userTransactions')
          .add(transaction.toMap());

      String id = docRef.id;
      await docRef.update({'id': id});

      // Update budget spent amount if expense
      if (transaction.type == 'expense') {
        await _updateBudgetSpent(transaction.category, transaction.amount);
      }

      // Check and apply rules
      await _applyRules(transaction);

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

  // Budgets
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

  // Rules
  Future<void> addRule(RuleModel rule) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .add(rule.toMap());

      String id = docRef.id;
      await docRef.update({'id': id});
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

  // Private helper methods
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

  Future<void> _applyRules(TransactionModel transaction) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .get();

      List<RuleModel> rules = snapshot.docs
          .map((doc) => RuleModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      for (RuleModel rule in rules) {
        bool conditionsMet = _checkRuleConditions(rule, transaction);

        if (conditionsMet) {
          await _executeRuleActions(rule, transaction);
          await _firestore
              .collection('rules')
              .doc(currentUserId)
              .collection('userRules')
              .doc(rule.id)
              .update({'lastTriggered': DateTime.now().toIso8601String()});
        }
      }
    } catch (e) {
      print('Error applying rules: $e');
    }
  }

  bool _checkRuleConditions(RuleModel rule, TransactionModel transaction) {
    if (rule.conditions['transactionType'] != null &&
        rule.conditions['transactionType'] != transaction.type) {
      return false;
    }

    if (rule.conditions['minAmount'] != null &&
        transaction.amount < rule.conditions['minAmount']) {
      return false;
    }

    if (rule.conditions['category'] != null &&
        rule.conditions['category'] != transaction.category) {
      return false;
    }

    return true;
  }

  Future<void> _executeRuleActions(RuleModel rule, TransactionModel transaction) async {
    if (rule.type == 'allocation' && rule.actions['allocateToSavings'] != null) {
      double savingsPercent = rule.actions['allocateToSavings'].toDouble();
      double savingsAmount = transaction.amount * (savingsPercent / 100);

      TransactionModel savings = TransactionModel(
        id: '',
        userId: currentUserId!,
        type: 'expense',
        category: 'Savings',
        amount: savingsAmount,
        description: 'Auto-allocated from ${transaction.description}',
        date: DateTime.now(),
      );

      await addTransaction(savings);
    }
  }

  // Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      if (currentUserId == null) {
        return {
          'totalIncome': 0.0,
          'totalExpenses': 0.0,
          'netAmount': 0.0,
          'weeklyIncome': 0.0,
          'weeklyExpenses': 0.0,
          'salaryIncome': 0.0,
          'gigIncome': 0.0,
        };
      }

      double totalIncome = 0;
      double totalExpenses = 0;
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

          // Categorize by source for hybrid earners
          if (transaction.source?.toLowerCase() == 'salary' ||
              transaction.category.toLowerCase() == 'salary') {
            salaryIncome += transaction.amount;
          } else {
            gigIncome += transaction.amount;
          }

          if (transaction.date.isAfter(weekStart)) {
            weeklyIncome += transaction.amount;
          }
        } else {
          totalExpenses += transaction.amount;
          if (transaction.date.isAfter(weekStart)) {
            weeklyExpenses += transaction.amount;
          }
        }
      }

      return {
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
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
        'netAmount': 0.0,
        'weeklyIncome': 0.0,
        'weeklyExpenses': 0.0,
        'salaryIncome': 0.0,
        'gigIncome': 0.0,
      };
    }
  }

  // User Profile
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

  // Transactions
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
          await _updateBudgetSpent(transaction.category, -transaction.amount);
        }

        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting transaction: $e');
      rethrow;
    }
  }

  // Delete Budget
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

  // Update Rules
  Future<void> updateRule(RuleModel rule) async {
    try {
      await _firestore
          .collection('rules')
          .doc(currentUserId)
          .collection('userRules')
          .doc(rule.id)
          .update(rule.toMap());
    } catch (e) {
      print('Error updating rule: $e');
      rethrow;
    }
  }

  // Delete Rule
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
}