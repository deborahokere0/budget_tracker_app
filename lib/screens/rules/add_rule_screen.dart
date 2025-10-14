import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/rule_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class AddRuleScreen extends StatefulWidget {
  final String ruleType;
  final RuleModel? existingRule;

  const AddRuleScreen({
    super.key,
    required this.ruleType,
    this.existingRule,
  });

  @override
  State<AddRuleScreen> createState() => _AddRuleScreenState();
}

class _AddRuleScreenState extends State<AddRuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _goalNameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  String _selectedCategory = 'Food';
  double _allocationPercent = 10.0;
  int _priority = 1;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isPiggyBank = false;
  UserModel? _currentUser;
  double _totalAllocationPercent = 0.0;

  final List<String> _categories = [
    'Food', 'Transport', 'Data', 'Entertainment',
    'Utilities', 'Savings', 'Emergency', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    if (widget.ruleType == 'allocation') {
      _calculateTotalAllocation();
    }

    // Pre-fill if editing
    if (widget.existingRule != null) {
      _prefillExistingRule();
    }
  }

  void _prefillExistingRule() {
    final rule = widget.existingRule!;
    _nameController.text = rule.name;
    _priority = rule.priority;
    _isActive = rule.isActive;

    switch (rule.type) {
      case 'allocation':
        _amountController.text = rule.conditions['minAmount']?.toString() ?? '';
        _allocationPercent = rule.actions['allocateToSavings']?.toDouble() ?? 10.0;
        break;
      case 'savings':
        _selectedCategory = rule.conditions['category'] ?? 'Food';
        _isPiggyBank = rule.isPiggyBank ?? false;
        if (!_isPiggyBank) {
          _goalNameController.text = rule.goalName ?? '';
          _targetAmountController.text = rule.targetAmount?.toString() ?? '';
        }
        break;
      case 'alert':
        _selectedCategory = rule.conditions['category'] ?? 'Food';
        _amountController.text = rule.conditions['threshold']?.toString() ?? '';
        break;
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await _firebaseService.getUserProfile(_firebaseService.currentUserId!);
      if (mounted) {
        setState(() => _currentUser = user);
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _calculateTotalAllocation() async {
    try {
      final rules = await _firebaseService.getRules().first;
      final allocationRules = rules.where((r) =>
      r.type == 'allocation' &&
          r.isActive &&
          (widget.existingRule == null || r.id != widget.existingRule!.id)
      ).toList();

      double total = 0.0;
      for (var rule in allocationRules) {
        total += (rule.actions['allocateToSavings'] ?? 0.0).toDouble();
      }

      if (mounted) {
        setState(() => _totalAllocationPercent = total);
      }
    } catch (e) {
      print('Error calculating allocation: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _goalNameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _saveRule() async {
    if (_formKey.currentState!.validate()) {
      // Validate monthly income for fixed income users
      if (widget.ruleType == 'allocation' && _currentUser?.incomeType == 'fixed') {
        if (_currentUser?.monthlyIncome == null || _currentUser!.monthlyIncome! <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Monthly income can\'t be 0. Please update your profile with your income'),
              backgroundColor: AppTheme.red,
            ),
          );
          return;
        }
      }
      // Validate allocation doesn't exceed 100%
      if (widget.ruleType == 'allocation') {
        final newTotal = _totalAllocationPercent + _allocationPercent;
        if (newTotal > 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Total allocation would be ${newTotal.toStringAsFixed(0)}%. Cannot exceed 100%'),
              backgroundColor: AppTheme.red,
            ),
          );
          return;
        }
      }

      setState(() => _isLoading = true);

      Map<String, dynamic> conditions = {};
      Map<String, dynamic> actions = {};
      double? targetAmount;
      double? currentAmount;
      String? goalName;
      bool? isPiggyBank;

      // Build conditions based on rule type
      switch (widget.ruleType) {
        case 'allocation':
          conditions['transactionType'] = 'income';
          conditions['minAmount'] = _currentUser?.incomeType == 'fixed'
              ? (_currentUser?.monthlyIncome ?? 0)
              : (double.tryParse(_amountController.text) ?? 0);
          actions['allocateToSavings'] = _allocationPercent;
          break;
        case 'savings':
          conditions['category'] = _selectedCategory;
          isPiggyBank = _isPiggyBank;
          if (!_isPiggyBank) {
            goalName = _goalNameController.text;
            targetAmount = double.tryParse(_targetAmountController.text) ?? 0;
            currentAmount = widget.existingRule?.currentAmount ?? 0.0;
          }
          break;
        case 'alert':
          conditions['category'] = _selectedCategory;
          conditions['threshold'] = double.tryParse(_amountController.text) ?? 0;
          actions['sendNotification'] = true;
          break;
        case 'boost':
          conditions['category'] = _selectedCategory;
          actions['boostAmount'] = double.tryParse(_amountController.text) ?? 0;
          break;
      }

      final rule = RuleModel(
        id: widget.existingRule?.id ?? '',
        userId: _firebaseService.currentUserId!,
        name: _nameController.text,
        type: widget.ruleType,
        conditions: conditions,
        actions: actions,
        priority: _priority,
        isActive: _isActive,
        createdAt: widget.existingRule?.createdAt ?? DateTime.now(),
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        goalName: goalName,
        isPiggyBank: isPiggyBank,
      );

      try {
        if (widget.existingRule != null) {
          await _firebaseService.updateRule(rule);
        } else {
          await _firebaseService.addRule(rule);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rule ${widget.existingRule != null ? "updated" : "created"} successfully'),
              backgroundColor: AppTheme.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving rule: $e'),
              backgroundColor: AppTheme.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.existingRule != null ? "Edit" : "Add"} ${_getRuleTypeTitle()} Rule'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rule Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Rule Name',
                  hintText: 'e.g., Save 20% of income',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a rule name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Rule Type Specific Fields
              _buildRuleTypeFields(),

              const SizedBox(height: 24),

              // Priority Slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priority: $_priority',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Slider(
                    value: _priority.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _priority.toString(),
                    activeColor: AppTheme.primaryBlue,
                    onChanged: (value) {
                      setState(() => _priority = value.toInt());
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Active Switch
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Rule will be applied automatically'),
                value: _isActive,
                activeThumbColor: AppTheme.green,
                onChanged: (value) {
                  setState(() => _isActive = value);
                },
              ),

              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveRule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  widget.existingRule != null ? 'Update Rule' : 'Save Rule',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleTypeFields() {
    switch (widget.ruleType) {
      case 'allocation':
        return Column(
          children: [
            // Show allocation summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _totalAllocationPercent + _allocationPercent > 100
                    ? AppTheme.red.withValues(alpha : 0.1)
                    : AppTheme.green.withValues(alpha : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Allocation:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${_totalAllocationPercent.toStringAsFixed(0)}%'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('This Rule:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${_allocationPercent.toStringAsFixed(0)}%'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        '${(_totalAllocationPercent + _allocationPercent).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _totalAllocationPercent + _allocationPercent > 100
                              ? AppTheme.red
                              : AppTheme.green,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Remaining:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${(100 - _totalAllocationPercent - _allocationPercent).toStringAsFixed(0)}%'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Minimum Income Amount
            if (_currentUser?.incomeType == 'fixed')
              Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                // child: Row(
                //   children: [
                //     Expanded(
                //       child: Column(
                //         crossAxisAlignment: CrossAxisAlignment.start,
                //         children: [
                //           const Text(
                //             'Monthly Salary',
                //             style: TextStyle(
                //               fontSize: 12,
                //               color: Colors.grey,
                //             ),
                //           ),
                //           const SizedBox(height: 4),
                //           Text(
                //             '₦${_currentUser?.monthlyIncome?.toStringAsFixed(0) ?? "0"}',
                //             style: const TextStyle(
                //               fontSize: 20,
                //               fontWeight: FontWeight.bold,
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //     // IconButton(
                //     //   icon: const Icon(Icons.edit, color: AppTheme.primaryBlue),
                //     //   onPressed: () async {
                //     //     await Navigator.push(
                //     //       context,
                //     //       MaterialPageRoute(builder: (_) => const ProfileScreen()),
                //     //     );
                //     //     _loadUserProfile();
                //     //   },
                //     // ),
                //   ],
                // ),
              )
            else
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Income Amount',
                  prefixText: '₦ ',
                  hintText: 'Apply when income is at least',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allocation Percentage: ${_allocationPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 16),
                ),
                Slider(
                  value: _allocationPercent,
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: '${_allocationPercent.toStringAsFixed(0)}%',
                  activeColor: AppTheme.green,
                  onChanged: (value) {
                    setState(() => _allocationPercent = value);
                  },
                ),
              ],
            ),
          ],
        );

      case 'savings':
        return Column(
          children: [
            // Piggy Bank Toggle
            SwitchListTile(
              title: const Text('Piggy Bank'),
              subtitle: const Text('General savings without specific goal'),
              value: _isPiggyBank,
              activeThumbColor: AppTheme.primaryBlue,
              onChanged: (value) {
                setState(() => _isPiggyBank = value);
              },
            ),
            const SizedBox(height: 16),

            if (!_isPiggyBank) ...[
              TextFormField(
                controller: _goalNameController,
                decoration: const InputDecoration(
                  labelText: 'Goal Name',
                  hintText: 'e.g., New Laptop, Janet Asebi',
                  prefixIcon: Icon(Icons.flag),
                ),
                validator: (value) {
                  if (!_isPiggyBank && (value == null || value.isEmpty)) {
                    return 'Please enter a goal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Amount',
                  prefixText: '₦ ',
                  hintText: 'How much to save',
                  prefixIcon: Icon(Icons.savings),
                ),
                validator: (value) {
                  if (!_isPiggyBank && (value == null || value.isEmpty)) {
                    return 'Please enter target amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            DropdownButtonFormField<String>(
              initialValue:_selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category to Save From',
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories
                  .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
            ),
          ],
        );

      case 'alert':
        return Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue:_selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories
                  .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Alert Threshold',
                prefixText: '₦ ',
                hintText: 'Alert when spending exceeds',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a threshold amount';
                }
                return null;
              },
            ),
          ],
        );

      case 'boost':
        return Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.rocket_launch,
                  size: 48,
                  color: AppTheme.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Boost rules coming soon!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI-powered optimization will be available in the next update',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _getRuleTypeTitle() {
    switch (widget.ruleType) {
      case 'allocation':
        return 'Auto-Allocation';
      case 'savings':
        return 'Savings';
      case 'alert':
        return 'Alert';
      case 'boost':
        return 'Boost';
      default:
        return '';
    }
  }
}