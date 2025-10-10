// lib/screens/rules/rules_screen.dart
import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/rule_model.dart';
import '../../theme/app_theme.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  Color _getRuleTypeColor(String type) {
    switch (type) {
      case 'allocation':
        return AppTheme.primaryBlue;
      case 'savings':
        return AppTheme.green;
      case 'alert':
        return AppTheme.orange;
      case 'boost':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getRuleTypeIcon(String type) {
    switch (type) {
      case 'allocation':
        return Icons.pie_chart;
      case 'savings':
        return Icons.savings;
      case 'alert':
        return Icons.notification_important;
      case 'boost':
        return Icons.trending_up;
      default:
        return Icons.rule;
    }
  }

  Future<void> _toggleRuleStatus(RuleModel rule) async {
    try {
      final updatedRule = RuleModel(
        id: rule.id,
        userId: rule.userId,
        name: rule.name,
        type: rule.type,
        conditions: rule.conditions,
        actions: rule.actions,
        priority: rule.priority,
        isActive: !rule.isActive,
        createdAt: rule.createdAt,
        lastTriggered: rule.lastTriggered,
      );

      await _firebaseService.updateRule(updatedRule);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rule ${updatedRule.isActive ? 'activated' : 'deactivated'}',
            ),
            backgroundColor: AppTheme.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRule(String ruleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: const Text('Are you sure you want to delete this rule?'),
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
        await _firebaseService.deleteRule(ruleId);
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
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.red,
            ),
          );
        }
      }
    }
  }

  void _showRuleDetails(RuleModel rule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getRuleTypeColor(rule.type).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getRuleTypeIcon(rule.type),
                      color: _getRuleTypeColor(rule.type),
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          rule.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getRuleTypeColor(rule.type),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailSection('Priority', 'Level ${rule.priority}'),
              _buildDetailSection(
                'Status',
                rule.isActive ? 'Active' : 'Inactive',
              ),
              _buildDetailSection(
                'Created',
                _formatDate(rule.createdAt),
              ),
              if (rule.lastTriggered != null)
                _buildDetailSection(
                  'Last Triggered',
                  _formatDate(rule.lastTriggered!),
                ),
              const SizedBox(height: 16),
              const Text(
                'Conditions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Automation Rules'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
      ),
      body: StreamBuilder<List<RuleModel>>(
        stream: _firebaseService.getRules(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading rules\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rule, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No rules yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create rules to automate your budgeting',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Add Rule feature coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Rule'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            );
          }

          final rules = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return _buildRuleCard(rule);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add Rule feature coming soon'),
            ),
          );
        },
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRuleCard(RuleModel rule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showRuleDetails(rule),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getRuleTypeColor(rule.type).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getRuleTypeIcon(rule.type),
                  color: _getRuleTypeColor(rule.type),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${rule.type.toUpperCase()} • Priority ${rule.priority}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (rule.lastTriggered != null)
                      Text(
                        'Last: ${_formatDate(rule.lastTriggered!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                value: rule.isActive,
                onChanged: (_) => _toggleRuleStatus(rule),
                activeThumbColor: AppTheme.green,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteRule(rule.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}