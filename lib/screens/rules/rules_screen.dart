import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/rule_model.dart';
import '../../theme/app_theme.dart';
import 'add_rule_screen.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      appBar: AppBar(
        title: const Text('Rules'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Auto-Allocate'),
            Tab(text: 'Savings'),
            Tab(text: 'Alerts'),
            Tab(text: 'Boost'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildAutoAllocateTab(),
            _buildSavingsTab(),
            _buildAlertsTab(),
            _buildBoostTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddRuleScreen(
                ruleType: _getCurrentRuleType(),
              ),
            ),
          );
        },
        backgroundColor: AppTheme.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getCurrentRuleType() {
    switch (_tabController.index) {
      case 0:
        return 'allocation';
      case 1:
        return 'savings';
      case 2:
        return 'alert';
      case 3:
        return 'boost';
      default:
        return 'allocation';
    }
  }

  Widget _buildAutoAllocateTab() {
    return StreamBuilder<List<RuleModel>>(
      stream: _firebaseService.getRules(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rules = snapshot.data!
            .where((rule) => rule.type == 'allocation')
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Allocation Visual
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Salary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₦350,000',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: 0.8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '80% of salary allocated',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Auto-Allocation Engine
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AUTO-ALLOCATION ENGINE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Determine the distribution of income into predefined budgets',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Saved Allocations
              if (rules.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SAVED ALLOCATIONS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...rules.map((rule) => _buildRuleItem(rule)).toList(),
              ] else
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.rule,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No allocation rules yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to create your first rule',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Savings Visual
          SizedBox(
            height: 200,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 150,
                    width: 150,
                    child: CircularProgressIndicator(
                      value: 0.7,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.green),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₦70,000',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '20% from Saved allocation',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Savings Engine
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SAVINGS ENGINE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Determine the distribution of income into predefined Budgets',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Savings Goals
          Row(
            children: [
              Expanded(
                child: _buildSavingsGoalCard(
                  'New Laptop',
                  480000,
                  0.7,
                  AppTheme.red,
                  'April 2025',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSavingsGoalCard(
                  'Janet Asebi',
                  100000,
                  0.4,
                  AppTheme.green,
                  'June 2025',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_active,
                    size: 64,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ALERTS ENGINE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stay ahead of bills and budgets! Choose when and how we notify you.',
                    style: TextStyle(
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoostTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rocket_launch,
              size: 80,
              color: AppTheme.orange,
            ),
            const SizedBox(height: 24),
            const Text(
              'Boost Coming Soon!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'AI-powered spending insights and optimization tips will be available here',
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(RuleModel rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            rule.isActive ? Icons.check_circle : Icons.circle_outlined,
            color: rule.isActive ? AppTheme.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getRuleDescription(rule),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.grey[600]),
            onPressed: () {
              // Handle edit
            },
          ),
          if (rule.priority > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.flag,
                color: Colors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  String _getRuleDescription(RuleModel rule) {
    switch (rule.type) {
      case 'allocation':
        double percent = rule.actions['allocateToSavings'] ?? 0;
        double minAmount = rule.conditions['minAmount'] ?? 0;
        return 'Allocate ${percent.toStringAsFixed(0)}% when income ≥ ₦${minAmount.toStringAsFixed(0)}';

      case 'savings':
        double savePercent = rule.actions['savePercent'] ?? 0;
        String category = rule.conditions['category'] ?? 'All';
        return 'Save ${savePercent.toStringAsFixed(0)}% from $category transactions';

      case 'alert':
        double threshold = rule.conditions['threshold'] ?? 0;
        String category = rule.conditions['category'] ?? 'All';
        return 'Alert when $category spending exceeds ₦${threshold.toStringAsFixed(0)}';

      case 'boost':
        return 'AI-powered optimization rule';

      default:
        return 'Custom rule with ${rule.conditions.length} conditions';
    }
  }

  Widget _buildSavingsGoalCard(String title, double target, double progress, Color color, String date) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₦${(target * progress).toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% saved since $date',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}