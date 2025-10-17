import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/alert_service.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'widgets/fixed_earner_dashboard.dart';
import 'widgets/variable_earner_dashboard.dart';
import 'widgets/hybrid_earner_dashboard.dart';
import 'widgets/enhanced_alert_banner.dart';
import 'transactions/add_transaction_screen.dart';
import 'rules/rules_screen.dart';
import 'transactions/transactions_list_screen.dart';
import 'profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  UserModel? _currentUser;
  Map<String, dynamic> _dashboardStats = {};
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadUserProfile();
      await _loadDashboardStats();

      // Check alerts after loading data
      if (_currentUser != null) {
        final alertService = AlertService(_currentUser!.uid);
        await alertService.checkAndTriggerAlerts();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    if (_firebaseService.currentUserId != null) {
      final user = await _firebaseService.getUserProfile(_firebaseService.currentUserId!);
      if (mounted) {
        setState(() => _currentUser = user);
      }
    } else {
      throw Exception('No authenticated user found');
    }
  }

  Future<void> _loadDashboardStats() async {
    final stats = await _firebaseService.getDashboardStats();
    if (mounted) {
      setState(() => _dashboardStats = stats);
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firebaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  void _navigateToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
    _loadUserProfile();
  }

  Widget _buildDashboard() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your dashboard...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentUser == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64),
            SizedBox(height: 16),
            Text('Unable to load user profile'),
          ],
        ),
      );
    }

    // Wrap dashboard with global alert overlay
    return GlobalAlertOverlay(
      userId: _currentUser!.uid,
      dashboardType: _currentUser!.incomeType,
      child: _buildDashboardByType(),
    );
  }

  Widget _buildDashboardByType() {
    switch (_currentUser!.incomeType) {
      case 'fixed':
        return FixedEarnerDashboard(
          user: _currentUser!,
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
          onRefresh: _loadDashboardStats,
        );
      default:
        return FixedEarnerDashboard(
          user: _currentUser!,
          onRefresh: _loadDashboardStats,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildDashboard(),
      // Wrap other pages with alerts too
      _currentUser != null
          ? GlobalAlertOverlay(
        userId: _currentUser!.uid,
        dashboardType: _currentUser!.incomeType,
        child: const TransactionsListScreen(),
      )
          : const TransactionsListScreen(),
      _currentUser != null
          ? GlobalAlertOverlay(
        userId: _currentUser!.uid,
        dashboardType: _currentUser!.incomeType,
        child: const RulesScreen(),
      )
          : const RulesScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      appBar: _selectedIndex == 0
          ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _navigateToProfile,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: _currentUser?.profileImageUrl != null
                    ? ClipOval(
                  child: Image.network(
                    _currentUser!.profileImageUrl!,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildProfileInitial();
                    },
                  ),
                )
                    : _buildProfileInitial(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
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
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        backgroundColor: AppTheme.green,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTransactionScreen(
                onTransactionAdded: _loadDashboardStats,
                initialTransactionType: 'expense',
              ),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }

  Widget _buildProfileInitial() {
    return Text(
      _currentUser?.fullName.substring(0, 1).toUpperCase() ?? 'U',
      style: const TextStyle(
        fontSize: 18,
        color: AppTheme.primaryBlue,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}