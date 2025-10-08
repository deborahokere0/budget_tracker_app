import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'widgets/fixed_earner_dashboard.dart';
import 'widgets/variable_earner_dashboard.dart';
import 'widgets/hybrid_earner_dashboard.dart';
import 'transactions/add_transaction_screen.dart';
import 'rules/rules_screen.dart';
import 'transactions/transactions_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  UserModel? _currentUser;
  int _selectedIndex = 0;
  Map<String, dynamic> _dashboardStats = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadDashboardStats();
  }

  Future<void> _loadUserProfile() async {
    if (_firebaseService.currentUserId != null) {
      final user = await _firebaseService.getUserProfile(_firebaseService.currentUserId!);
      setState(() => _currentUser = user);
    }
  }

  Future<void> _loadDashboardStats() async {
    final stats = await _firebaseService.getDashboardStats();
    setState(() => _dashboardStats = stats);
  }

  Widget _buildDashboard() {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentUser!.incomeType) {
      case 'fixed':
        return FixedEarnerDashboard(
          user: _currentUser!,
          stats: _dashboardStats,
          onRefresh: _loadDashboardStats,
        );
      case 'variable':
        return VariableEarnerDashboard(
          user: _currentUser!,
          stats: _dashboardStats,
          onRefresh: _loadDashboardStats,
        );
      case 'hybrid':
        return HybridEarnerDashboard(
          user: _currentUser!,
          stats: _dashboardStats,
          onRefresh: _loadDashboardStats,
        );
      default:
        return FixedEarnerDashboard(
          user: _currentUser!,
          stats: _dashboardStats,
          onRefresh: _loadDashboardStats,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildDashboard(),
      const TransactionsListScreen(),
      const RulesScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rule),
            label: 'Rules',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.green,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTransactionScreen(
                onTransactionAdded: _loadDashboardStats,
              ),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}