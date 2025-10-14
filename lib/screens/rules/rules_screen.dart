import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../models/rule_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../profile/profile_screen.dart';
import 'add_rule_screen.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentRuleType {
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

  Future<void> _toggleRule(RuleModel rule) async {
    try {
      await _firebaseService.updateRule(
        rule.copyWith(isActive: !rule.isActive),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rule ${!rule.isActive ? 'activated' : 'deactivated'}',
            ),
            backgroundColor: AppTheme.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  Future<void> _deleteRule(RuleModel rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Text('Delete "${rule.name}"?'),
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

    if (confirm == true) {
      try {
        await _firebaseService.deleteRule(rule.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rule deleted'),
              backgroundColor: AppTheme.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
          );
        }
      }
    }
  }

  void _editRule(RuleModel rule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRuleScreen(ruleType: rule.type, existingRule: rule),
      ),
    );
  }

  void _showRuleDetails(RuleModel rule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              rule.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              rule.type.toUpperCase(),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const Divider(height: 30),
            _buildDetailRow('Priority', 'Level ${rule.priority}'),
            _buildDetailRow('Status', rule.isActive ? 'Active' : 'Inactive'),
            _buildDetailRow(
              'Created',
              '${rule.createdAt.day}/${rule.createdAt.month}/${rule.createdAt.year}',
            ),

            if (rule.type == 'savings' &&
                rule.isPiggyBank != null &&
                !rule.isPiggyBank!) ...[
              const SizedBox(height: 16),
              _buildDetailRow('Goal', rule.goalName ?? 'N/A'),
              _buildDetailRow(
                'Target',
                CurrencyFormatter.format(rule.targetAmount ?? 0),
              ),
              _buildDetailRow(
                'Current',
                CurrencyFormatter.format(rule.currentAmount ?? 0),
              ),
              _buildDetailRow(
                'Progress',
                '${rule.savingsProgress.toStringAsFixed(1)}%',
              ),
            ],

            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_getRuleDescription(rule)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Conditions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                rule.conditions.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('\n'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Actions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                rule.actions.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('\n'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _editRule(rule);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Rule"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteRule(rule);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text("Delete"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _getRuleDescription(RuleModel rule) {
    switch (rule.type) {
      case 'allocation':
        double percent = rule.actions['allocateToSavings'] ?? 0;
        double minAmount = rule.conditions['minAmount'] ?? 0;
        return 'Allocate ${percent.toStringAsFixed(0)}% when income ≥ ${CurrencyFormatter.format(minAmount)}';

      case 'savings':
        if (rule.isPiggyBank == true) {
          return 'Save to Piggy Bank from ${rule.conditions['category'] ?? 'All'} transactions';
        }
        String goalName = rule.goalName ?? 'Unknown Goal';
        double target = rule.targetAmount ?? 0;
        return 'Save ${CurrencyFormatter.format(target)} for $goalName';

      case 'alert':
        double threshold = rule.conditions['threshold'] ?? 0;
        String category = rule.conditions['category'] ?? 'All';
        return 'Alert when $category spending exceeds ${CurrencyFormatter.format(threshold)}';

      case 'boost':
        return 'AI-powered optimization rule';

      default:
        return 'Custom rule with ${rule.conditions.length} conditions';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      appBar: AppBar(
        title: const Text('Rules', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              builder: (_) => AddRuleScreen(ruleType: _currentRuleType),
            ),
          );
        },
        backgroundColor: AppTheme.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAutoAllocateTab() {
    return StreamBuilder<List<RuleModel>>(
      stream: _firebaseService.getRules(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading rules',
                  style: TextStyle(color: Colors.red[600]),
                ),
              ],
            ),
          );
        }

        final allocationRules =
            snapshot.data?.where((r) => r.type == 'allocation').toList() ?? [];

        // Calculate total allocation
        double totalAllocated = 0;
        for (var rule in allocationRules.where((r) => r.isActive)) {
          totalAllocated += (rule.actions['allocateToSavings'] ?? 0.0)
              .toDouble();
        }
        double remaining = 100 - totalAllocated;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Allocation Summary
              FutureBuilder<UserModel?>(
                future: _firebaseService.getUserProfile(
                  _firebaseService.currentUserId!,
                ),
                builder: (context, userSnapshot) {
                  final monthlyIncome = userSnapshot.data?.monthlyIncome ?? 0.0;

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monthly Income',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    CurrencyFormatter.format(monthlyIncome),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: AppTheme.primaryBlue,
                                size: 28,
                              ),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileScreen(),
                                  ),
                                );
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: totalAllocated / 100,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            totalAllocated > 100
                                ? AppTheme.red
                                : AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${totalAllocated.toStringAsFixed(0)}% allocated',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${remaining.toStringAsFixed(0)}% remaining',
                              style: TextStyle(
                                fontSize: 12,
                                color: remaining < 0
                                    ? AppTheme.red
                                    : AppTheme.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Saved Allocations
              if (allocationRules.isNotEmpty) ...[
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
                ...allocationRules.map((rule) => _buildRuleItem(rule)),
              ] else
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.rule, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No allocation rules yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to create your first rule',
                        style: TextStyle(color: Colors.grey[500]),
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
    return StreamBuilder<List<RuleModel>>(
      stream: _firebaseService.getRules(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final savingsRules =
            snapshot.data?.where((r) => r.type == 'savings').toList() ?? [];

        // Calculate total savings
        double totalSavings = 0;
        for (var rule in savingsRules) {
          totalSavings += (rule.currentAmount ?? 0.0);
        }

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
                          value: totalSavings > 0 ? 0.7 : 0,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.green,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            CurrencyFormatter.format(totalSavings),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Total Savings',
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
                      'Save towards specific goals or general piggy bank',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Savings Goals
              if (savingsRules
                  .where((r) => r.isPiggyBank != true)
                  .isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SAVINGS GOALS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: savingsRules
                      .where((r) => r.isPiggyBank != true)
                      .map((rule) => _buildSavingsGoalCard(rule))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Piggy Bank
              if (savingsRules.any((r) => r.isPiggyBank == true)) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PIGGY BANK',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...savingsRules
                    .where((r) => r.isPiggyBank == true)
                    .map((rule) => _buildRuleItem(rule)),
                const SizedBox(height: 20),
              ],

              if (savingsRules.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.savings, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No savings goals yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to create your first savings goal',
                        style: TextStyle(color: Colors.grey[500]),
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

  Widget _buildAlertsTab() {
    return StreamBuilder<List<RuleModel>>(
      stream: _firebaseService.getRules(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final alertRules =
            snapshot.data?.where((r) => r.type == 'alert').toList() ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
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
                      style: TextStyle(color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Alert Rules
              if (alertRules.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ALERT RULES',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...alertRules.map((rule) => _buildRuleItem(rule)),
              ] else
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(Icons.rule, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No alert rules yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to create your first alert rule',
                        style: TextStyle(color: Colors.grey[500]),
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

  Widget _buildBoostTab() {
    return StreamBuilder<List<RuleModel>>(
      stream: _firebaseService.getRules(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final boostRules =
            snapshot.data?.where((r) => r.type == 'boost').toList() ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Icon(Icons.rocket_launch, size: 80, color: AppTheme.orange),
              const SizedBox(height: 24),
              const Text(
                'Boost Coming Soon!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'AI-powered spending insights and optimization tips will be available here',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),

              if (boostRules.isNotEmpty) ...[
                const SizedBox(height: 40),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'BOOST RULES (PREVIEW)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...boostRules.map((rule) => _buildRuleItem(rule)),
              ],
            ],
          ),
        );
      },
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
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleRule(rule),
            child: Icon(
              rule.isActive ? Icons.check_circle : Icons.circle_outlined,
              color: rule.isActive ? AppTheme.green : Colors.grey,
              size: 28,
            ),
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
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getRuleDescription(rule),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            onPressed: () => _showRuleDetails(rule),
          ),
          if (rule.priority >= 4)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flag, color: Colors.white, size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalCard(RuleModel rule) {
    final progress = rule.savingsProgress / 100;
    final colors = [
      AppTheme.red,
      AppTheme.green,
      Colors.purple,
      AppTheme.orange,
      AppTheme.primaryBlue,
    ];
    final color = colors[rule.name.hashCode % colors.length];

    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rule.goalName ?? 'Unknown',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(rule.currentAmount ?? 0),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: 8),
          Text(
            '${rule.savingsProgress.toStringAsFixed(0)}% of ${CurrencyFormatter.format(rule.targetAmount ?? 0)}',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
