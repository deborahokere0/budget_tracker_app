import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firebase_service.dart';
import '../../models/rule_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../constants/category_constants.dart';
import '../../utils/currency_formatter.dart';

class AddRuleScreen extends StatefulWidget {
  final String ruleType;
  final RuleModel? existingRule;
  final String? prefilledCategory;

  const AddRuleScreen({
    super.key,
    required this.ruleType,
    this.existingRule,
    this.prefilledCategory,
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

  String _selectedCategory = CategoryConstants.expenseCategories.first;
  //double _allocationPercent = 10.0;
  int _priority = 1;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isPiggyBank = false;
  UserModel? _currentUser;
  double _totalAllocationPercent = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.existingRule != null) {
      _prefillExistingRule();
    } else if (widget.prefilledCategory != null) {
      _selectedCategory = widget.prefilledCategory!;
      if (widget.ruleType == 'allocation') {
        _nameController.text = '${widget.prefilledCategory} Budget Allocation';
      } else if (widget.ruleType == 'alert') {
        _nameController.text = '${widget.prefilledCategory} Budget Alert';
      }
    } else {
      _selectedCategory = CategoryConstants.expenseCategories.first;
    }

    _loadUserProfile();
    if (widget.ruleType == 'allocation') {
      _calculateTotalAllocation();
    }
  }

  void _prefillExistingRule() {
    final rule = widget.existingRule!;
    _nameController.text = rule.name;
    _priority = rule.priority;
    _isActive = rule.isActive;

    switch (rule.type) {
      case 'allocation':
        _selectedCategory = rule.conditions['category'] ?? CategoryConstants.expenseCategories.first;
        _amountController.text = rule.conditions['amountValue']?.toString() ?? '';
        _amountType = rule.conditions['amountType'] as String? ?? 'amount';
        break;
      case 'savings':
        _isPiggyBank = rule.isPiggyBank ?? false;
        if (!_isPiggyBank) {
          _goalNameController.text = rule.goalName ?? '';
          _targetAmountController.text = rule.targetAmount?.toString() ?? '';
        }
        break;
      case 'alert':
        _selectedCategory = rule.conditions['category'] ?? CategoryConstants.expenseCategories.first;
        // _amountController.text = rule.conditions['threshold']?.toString() ?? '';
        _thresholdType = rule.conditions['thresholdType'] as String? ?? 'amount';
        final thresholdValue = rule.conditions['thresholdValue'] as num? ?? 0.0;
        _amountController.text = thresholdValue.toString();
        break;
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await _firebaseService.getUserProfile(_firebaseService.currentUserId!);
      if (mounted) {
        setState(() => _currentUser = user);
        if (widget.ruleType == 'allocation') {
          _calculateTotalAllocation();
        }
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

      // Get user's monthly income
      final monthlyIncome = _currentUser?.monthlyIncome ?? 0.0;

      if (monthlyIncome == 0) {
        if (mounted) {
          setState(() => _totalAllocationPercent = 0.0);
        }
        return;
      }

      for (var rule in allocationRules) {
        final amountType = rule.conditions['amountType'] as String? ?? 'amount';
        final amountValue = (rule.conditions['amountValue'] as num?)?.toDouble() ?? 0.0;

        double percentageValue = 0.0;

        if (amountType == 'percentage') {
          percentageValue = amountValue;
        } else if (amountType == 'amount') {
          // Convert amount to percentage
          percentageValue = (amountValue / monthlyIncome) * 100;
        }

        total += percentageValue;
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
        final totalAllocation = _getTotalAllocation();
        if (totalAllocation > 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Total allocation would be ${totalAllocation.toStringAsFixed(
                      0)}%. Cannot exceed 100%'
              ),
              backgroundColor: AppTheme.red,
              duration: const Duration(seconds: 4),
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
          conditions['category'] = _selectedCategory;
          conditions['amountType'] = _amountType;
          conditions['amountValue'] = double.tryParse(_amountController.text) ?? 0;
          break;

        case 'savings':
          isPiggyBank = _isPiggyBank;
          if (!_isPiggyBank) {
            goalName = _goalNameController.text;
            targetAmount = double.tryParse(_targetAmountController.text) ?? 0;
            currentAmount = widget.existingRule?.currentAmount ?? 0.0;
          }
          break;

        case 'alert':
          conditions['category'] = _selectedCategory;
          conditions['thresholdType'] = _thresholdType; // 'amount' or 'percentage'
          conditions['thresholdValue'] = double.tryParse(_amountController.text) ?? 0;
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
      //Color chipColor;
        return Column(
          children: [
            // Category Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(CategoryConstants.getIcon(_selectedCategory)),
              ),
              items: CategoryConstants.expenseCategories
                  .map((category) => DropdownMenuItem(
                value: category,
                child: Row(
                  children: [
                    Icon(
                      CategoryConstants.getIcon(category),
                      size: 20,
                      color: CategoryConstants.getColor(category),
                    ),
                    const SizedBox(width: 12),
                    Text(category),
                  ],
                ),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
            ),
            const SizedBox(height: 16),

            // Amount Type Toggle
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Amount (₦)'),
                    selected: _amountType == 'amount',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _amountType = 'amount';
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Percentage (%)'),
                    selected: _amountType == 'percentage',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _amountType = 'percentage';
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount/Percentage Input
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _amountType == 'amount' ? 'Budget Amount' : 'Budget Percentage',
                prefixText: _amountType == 'amount' ? '₦ ' : null,
                suffixText: _amountType == 'percentage' ? '%' : null,
                hintText: _amountType == 'amount' ? '80000' : '40',
              ),
              // ADD THIS onChanged callback
              onChanged: (value) {
                setState(() {}); // Trigger rebuild to update allocation summary
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final num = double.tryParse(value);
                if (num == null || num <= 0) {
                  return 'Please enter a valid amount';
                }
                if (_amountType == 'percentage' && num > 100) {
                  return 'Percentage cannot exceed 100%';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Show calculated value
            if (_amountController.text.isNotEmpty && _currentUser != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _amountType == 'amount' ? 'As percentage:' : 'As amount:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _getCalculatedValue(),
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Allocation summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getTotalAllocation() > 100
                    ? AppTheme.red.withValues(alpha: 0.1)
                    : AppTheme.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildAllocationRow(
                    'Current Allocation:',
                    '${_totalAllocationPercent.toStringAsFixed(0)}%',
                  ),
                  _buildAllocationRow(
                    'This Rule:',
                    '${_getCurrentRulePercent().toStringAsFixed(0)}%',
                  ),
                  const Divider(),
                  _buildAllocationRow(
                    'Total:',
                    '${_getTotalAllocation().toStringAsFixed(0)}%',
                    bold: true,
                    color: _getTotalAllocation() > 100 ? AppTheme.red : AppTheme.green,
                  ),
                  _buildAllocationRow(
                    'Remaining:',
                    '${(100 - _getTotalAllocation()).toStringAsFixed(0)}%',
                  ),
                ],
              ),
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

          ],
        );

      case 'alert':
        return FutureBuilder<List<RuleModel>>(
          future: _firebaseService.getRules().first,
          builder: (context, snapshot) {
            final allocationRules = snapshot.data
                ?.where((r) => r.type == 'allocation')
                .toList() ?? [];

            final categoriesWithBudgets = allocationRules
                .map((r) => r.conditions['category'] as String?)
                .where((c) => c != null)
                .cast<String>()
                .toList();

            if (categoriesWithBudgets.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.orange),
                ),
                child: Column(
                  children: [
                    Icon(Icons.warning, size: 48, color: AppTheme.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'No Budgets Available',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create auto-allocation rules first to set budgets for categories.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            // Ensure selected category is valid
            if (!categoriesWithBudgets.contains(_selectedCategory)) {
              _selectedCategory = categoriesWithBudgets.first;
            }

            return Column(
              children: [
                // Category dropdown (filtered)
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category (with budget)',
                    prefixIcon: Icon(CategoryConstants.getIcon(_selectedCategory)),
                  ),
                  items: categoriesWithBudgets.map((category) {
                    final rule = allocationRules.firstWhere(
                          (r) => r.conditions['category'] == category,
                    );
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(
                            CategoryConstants.getIcon(category),
                            size: 20,
                            color: rule.isActive
                                ? CategoryConstants.getColor(category)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            category,
                            style: TextStyle(
                              color: rule.isActive ? Colors.black : Colors.grey,
                            ),
                          ),
                          if (!rule.isActive) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(inactive)',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value!);
                  },
                ),

                const SizedBox(height: 16),

                // Info about budget calculation
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentUser?.incomeType == 'variable' || _currentUser?.incomeType == 'hybrid'
                              ? 'Budget will be set to threshold ÷ 4 for weekly tracking'
                              : 'Budget will be set to this threshold amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Threshold Type Toggle
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Amount (₦)'),
                        selected: _thresholdType == 'amount',
                        onSelected: (selected) {
                          if (selected) setState(() => _thresholdType = 'amount');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Percentage (%)'),
                        selected: _thresholdType == 'percentage',
                        onSelected: (selected) {
                          if (selected) setState(() => _thresholdType = 'percentage');
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Threshold Input
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: _thresholdType == 'amount'
                        ? 'Alert Threshold (Monthly)'
                        : 'Alert Threshold (%)',
                    prefixText: _thresholdType == 'amount' ? '₦ ' : null,
                    suffixText: _thresholdType == 'percentage' ? '%' : null,
                    hintText: _thresholdType == 'amount'
                        ? 'e.g., 50000'
                        : 'e.g., 75',
                    helperText: _currentUser?.incomeType == 'variable' || _currentUser?.incomeType == 'hybrid'
                        ? 'Weekly budget will be calculated automatically'
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a threshold';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid amount';
                    }
                    if (_thresholdType == 'percentage' && amount > 100) {
                      return 'Percentage cannot exceed 100%';
                    }
                    return null;
                  },
                ),
              ],
            );
          },
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

  String _amountType = 'amount';

  String _thresholdType = 'amount'; // or 'percentage'

  String _getCalculatedValue() {
    if (_currentUser == null || _amountController.text.isEmpty) return '-';

    final value = double.tryParse(_amountController.text) ?? 0;
    final monthlyIncome = _currentUser!.monthlyIncome ?? 0;

    if (monthlyIncome == 0) return '-';

    if (_amountType == 'amount') {
      final percent = (value / monthlyIncome * 100).toStringAsFixed(1);
      return '$percent%';
    } else {
      final amount = (monthlyIncome * value / 100);
      return CurrencyFormatter.format(amount);
    }
  }

  double _getCurrentRulePercent() {
    if (_currentUser == null || _amountController.text.isEmpty) return 0;

    final value = double.tryParse(_amountController.text) ?? 0;
    final monthlyIncome = _currentUser!.monthlyIncome ?? 0;

    if (monthlyIncome == 0) return 0;

    if (_amountType == 'amount') {
      return value / monthlyIncome * 100;
    } else {
      return value;
    }
  }

  double _getTotalAllocation() {
    return _totalAllocationPercent + _getCurrentRulePercent();
  }

  Widget _buildAllocationRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}