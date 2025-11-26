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
  int _priority = 1;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isPiggyBank = false;
  UserModel? _currentUser;
  double _totalAllocationPercent = 0.0;

  // Income allocation specific fields
  String _incomeSource = 'all';
  String _allocationType = 'percentage';
  String _targetCategory = CategoryConstants.expenseCategories.first;
  String _amountType = 'amount';
  String _thresholdType = 'amount';

  List<String> get incomeSourceOptions => [
    'all',
    ...CategoryConstants.incomeCategories,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingRule != null) {
      _prefillExistingRule();
    } else if (widget.prefilledCategory != null) {
      _selectedCategory = widget.prefilledCategory!;
      _targetCategory = widget.prefilledCategory!;
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
      case 'income_allocation':
        _incomeSource = rule.incomeSource ?? 'all';
        _allocationType = rule.allocationType ?? 'percentage';
        _amountController.text = rule.allocationValue?.toString() ?? '';
        _targetCategory =
            rule.targetCategory ?? CategoryConstants.expenseCategories.first;
        break;
      case 'allocation':
        _selectedCategory =
            rule.conditions['category'] ??
            CategoryConstants.expenseCategories.first;
        _amountController.text =
            rule.conditions['amountValue']?.toString() ?? '';
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
        _selectedCategory =
            rule.conditions['category'] ??
            CategoryConstants.expenseCategories.first;
        _thresholdType =
            rule.conditions['thresholdType'] as String? ?? 'amount';
        final thresholdValue = rule.conditions['thresholdValue'] as num? ?? 0.0;
        _amountController.text = thresholdValue.toString();
        break;
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await _firebaseService.getUserProfile(
        _firebaseService.currentUserId!,
      );
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
      final allocationRules = rules
          .where(
            (r) =>
                r.type == 'allocation' &&
                r.isActive &&
                (widget.existingRule == null ||
                    r.id != widget.existingRule!.id),
          )
          .toList();

      double total = 0.0;
      final monthlyIncome = _currentUser?.monthlyIncome ?? 0.0;

      if (monthlyIncome == 0) {
        if (mounted) {
          setState(() => _totalAllocationPercent = 0.0);
        }
        return;
      }

      for (var rule in allocationRules) {
        final amountType = rule.conditions['amountType'] as String? ?? 'amount';
        final amountValue =
            (rule.conditions['amountValue'] as num?)?.toDouble() ?? 0.0;
        double percentageValue = 0.0;

        if (amountType == 'percentage') {
          percentageValue = amountValue;
        } else if (amountType == 'amount') {
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

  double _getTotalAllocation() {
    if (_currentUser?.monthlyIncome == null ||
        _currentUser!.monthlyIncome! <= 0) {
      return _totalAllocationPercent;
    }

    final currentValue = double.tryParse(_amountController.text) ?? 0.0;
    double currentPercentage = 0.0;

    if (_amountType == 'percentage') {
      currentPercentage = currentValue;
    } else {
      currentPercentage = (currentValue / _currentUser!.monthlyIncome!) * 100;
    }

    return _totalAllocationPercent + currentPercentage;
  }

  @override
  Widget build(BuildContext context) {
    // Show income allocation UI for variable earners
    if (_currentUser?.incomeType == 'variable' &&
        widget.ruleType == 'allocation') {
      return _buildIncomeAllocationScreen();
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: Text(
          widget.existingRule != null
              ? 'Edit ${_getRuleTypeName()} Rule'
              : 'Add ${_getRuleTypeName()} Rule',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRuleNameField(),
                    const SizedBox(height: 16),
                    ..._buildRuleSpecificFields(),
                    const SizedBox(height: 16),
                    _buildPrioritySelector(),
                    const SizedBox(height: 16),
                    _buildActiveToggle(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildIncomeAllocationScreen() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text(
          'Add Income Allocation Rule',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVariableEarnerIndicator(),
                    const SizedBox(height: 16),
                    _buildRuleNameField(),
                    const SizedBox(height: 16),
                    _buildIncomeAllocationFields(),
                    const SizedBox(height: 16),
                    _buildPrioritySelector(),
                    const SizedBox(height: 16),
                    _buildActiveToggle(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildVariableEarnerIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Variable Earner Mode',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This rule will auto-allocate from each income you receive to create weekly budgets',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Rule Name',
        hintText: 'e.g., ${_getNameHint()}',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) =>
          value?.isEmpty ?? true ? 'Please enter a rule name' : null,
    );
  }

  Widget _buildIncomeAllocationFields() {
    return Column(
      children: [
        // Income Source Selector
        DropdownButtonFormField<String>(
          initialValue: _incomeSource,
          decoration: const InputDecoration(
            labelText: 'Apply to Income From',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          items: incomeSourceOptions.map((source) {
            return DropdownMenuItem(
              value: source,
              child: Text(source == 'all' ? 'All Income Sources' : source),
            );
          }).toList(),
          onChanged: (value) => setState(() => _incomeSource = value!),
        ),
        const SizedBox(height: 16),

        // Allocation Type
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Percentage'),
                subtitle: const Text('% of income'),
                value: 'percentage',
                groupValue: _allocationType,
                onChanged: (value) => setState(() {
                  _allocationType = value!;
                  _amountController.clear();
                }),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Fixed'),
                subtitle: const Text('₦ amount'),
                value: 'fixed',
                groupValue: _allocationType,
                onChanged: (value) => setState(() {
                  _allocationType = value!;
                  _amountController.clear();
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Allocation Value
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: _allocationType == 'percentage'
                ? 'Percentage to Allocate'
                : 'Amount to Allocate',
            hintText: _allocationType == 'percentage'
                ? 'e.g., 30'
                : 'e.g., 5000',
            suffixText: _allocationType == 'percentage' ? '%' : '₦',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please enter an allocation value';
            }
            final amount = double.tryParse(value!);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid amount';
            }
            if (_allocationType == 'percentage' && amount > 100) {
              return 'Percentage cannot exceed 100%';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Target Category
        DropdownButtonFormField<String>(
          initialValue: _targetCategory,
          decoration: const InputDecoration(
            labelText: 'Allocate to Budget Category',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          items: CategoryConstants.expenseCategories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Row(
                children: [
                  Icon(
                    CategoryConstants.getIcon(category),
                    size: 20,
                    color: CategoryConstants.getColor(category),
                  ),
                  const SizedBox(width: 8),
                  Text(category),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _targetCategory = value!),
        ),

        const SizedBox(height: 16),

        // Info Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How it works:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _allocationType == 'percentage'
                          ? 'Every time you receive ${_incomeSource == "all" ? "any income" : _incomeSource}, '
                                '${_amountController.text.isEmpty ? "X" : _amountController.text}% will be allocated to $_targetCategory weekly budget.'
                          : 'Every time you receive ${_incomeSource == "all" ? "any income" : _incomeSource}, '
                                '₦${_amountController.text.isEmpty ? "X" : _amountController.text} will be allocated to $_targetCategory weekly budget.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRuleSpecificFields() {
    switch (widget.ruleType) {
      case 'alert':
        return _buildAlertFields();
      case 'savings':
        return _buildSavingsFields();
      case 'allocation':
        return _buildAllocationFields();
      default:
        return [];
    }
  }

  List<Widget> _buildAlertFields() {
    return [
      DropdownButtonFormField<String>(
        initialValue: _selectedCategory,
        decoration: const InputDecoration(
          labelText: 'Budget Category',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        items: CategoryConstants.expenseCategories.map((category) {
          return DropdownMenuItem(value: category, child: Text(category));
        }).toList(),
        onChanged: (value) => setState(() => _selectedCategory = value!),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: RadioListTile<String>(
              title: const Text('Percentage'),
              value: 'percentage',
              groupValue: _thresholdType,
              onChanged: (value) => setState(() => _thresholdType = value!),
            ),
          ),
          Expanded(
            child: RadioListTile<String>(
              title: const Text('Amount'),
              value: 'amount',
              groupValue: _thresholdType,
              onChanged: (value) => setState(() => _thresholdType = value!),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _amountController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: _thresholdType == 'percentage'
              ? 'Alert at % of Budget'
              : 'Alert at Amount Spent',
          suffixText: _thresholdType == 'percentage' ? '%' : '₦',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Please enter a threshold value';
          return null;
        },
      ),
    ];
  }

  List<Widget> _buildSavingsFields() {
    return [
      SwitchListTile(
        title: const Text('Piggybank Savings'),
        subtitle: const Text('Save without a specific goal'),
        value: _isPiggyBank,
        onChanged: (value) => setState(() => _isPiggyBank = value),
        activeThumbColor: AppTheme.green,
      ),
      if (!_isPiggyBank) ...[
        const SizedBox(height: 16),
        TextFormField(
          controller: _goalNameController,
          decoration: const InputDecoration(
            labelText: 'Goal Name',
            hintText: 'e.g., New Phone',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) => !_isPiggyBank && (value?.isEmpty ?? true)
              ? 'Please enter a goal name'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _targetAmountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Target Amount',
            prefixText: '₦ ',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (!_isPiggyBank && (value?.isEmpty ?? true)) {
              return 'Please enter a target amount';
            }
            return null;
          },
        ),
      ],
    ];
  }

  List<Widget> _buildAllocationFields() {
    // For fixed earners - existing allocation logic
    return [
      DropdownButtonFormField<String>(
        initialValue: _selectedCategory,
        decoration: const InputDecoration(
          labelText: 'Budget Category',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        items: CategoryConstants.expenseCategories.map((category) {
          return DropdownMenuItem(value: category, child: Text(category));
        }).toList(),
        onChanged: (value) => setState(() => _selectedCategory = value!),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _amountController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Allocation Amount',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Please enter an amount';
          return null;
        },
      ),
    ];
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rule Priority',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              const Icon(Icons.flag, color: AppTheme.primaryBlue),
              const SizedBox(width: 16),
              Expanded(
                child: Slider(
                  value: _priority.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _getPriorityLabel(_priority),
                  activeColor: _getPriorityColor(_priority),
                  onChanged: (value) =>
                      setState(() => _priority = value.round()),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getPriorityColor(_priority).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getPriorityColor(_priority)),
                ),
                child: Text(
                  _getPriorityLabel(_priority),
                  style: TextStyle(
                    color: _getPriorityColor(_priority),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveToggle() {
    return SwitchListTile(
      title: const Text('Rule Active'),
      subtitle: const Text('Enable or disable this rule'),
      value: _isActive,
      onChanged: (value) => setState(() => _isActive = value),
      activeThumbColor: AppTheme.green,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveRule,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          padding: const EdgeInsets.all(16),
        ),
        child: Text(
          widget.existingRule != null ? 'Update Rule' : 'Create Rule',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Lowest';
      case 2:
        return 'Low';
      case 3:
        return 'Medium';
      case 4:
        return 'High';
      case 5:
        return 'Highest';
      default:
        return 'Medium';
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.grey;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getRuleTypeName() {
    switch (widget.ruleType) {
      case 'income_allocation':
        return 'Income Allocation';
      case 'alert':
        return 'Alert';
      case 'savings':
        return 'Savings';
      case 'allocation':
        return 'Budget Allocation';
      default:
        return 'Rule';
    }
  }

  String _getNameHint() {
    switch (widget.ruleType) {
      case 'income_allocation':
        return '30% of Gig Income to Food';
      case 'alert':
        return 'Food Budget 80% Alert';
      case 'savings':
        return 'Emergency Fund';
      case 'allocation':
        return 'Monthly Food Budget';
      default:
        return 'My Rule';
    }
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate for fixed income users
    if (widget.ruleType == 'allocation' &&
        _currentUser?.incomeType == 'fixed') {
      if (_currentUser?.monthlyIncome == null ||
          _currentUser!.monthlyIncome! <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Monthly income can\'t be 0. Please update your profile',
            ),
            backgroundColor: AppTheme.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> conditions = {};
      Map<String, dynamic> actions = {};

      // For variable earners creating allocation rule
      if (_currentUser?.incomeType == 'variable' &&
          widget.ruleType == 'allocation') {
        await _firebaseService.createIncomeAllocationRule(
          ruleName: _nameController.text.trim(),
          incomeSource: _incomeSource,
          allocationType: _allocationType,
          allocationValue: double.parse(_amountController.text),
          targetCategory: _targetCategory,
          priority: _priority,
        );
      } else {
        // Handle other rule types
        switch (widget.ruleType) {
          case 'alert':
            conditions = {
              'category': _selectedCategory,
              'thresholdType': _thresholdType,
              'thresholdValue': double.parse(_amountController.text),
            };
            actions = {'notificationType': 'push', 'frequency': 'daily'};
            break;
          case 'savings':
            // Existing savings logic
            break;
          case 'allocation':
            // Fixed earner allocation logic
            break;
        }

        final rule = RuleModel(
          id: widget.existingRule?.id ?? '',
          userId: _firebaseService.currentUserId!,
          name: _nameController.text.trim(),
          type: widget.ruleType,
          conditions: conditions,
          actions: actions,
          priority: _priority,
          isActive: _isActive,
          createdAt: widget.existingRule?.createdAt ?? DateTime.now(),
        );

        if (widget.existingRule != null) {
          await _firebaseService.updateRule(rule);
        } else {
          await _firebaseService.addRule(rule);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingRule != null
                  ? 'Rule updated successfully'
                  : 'Rule created successfully',
            ),
            backgroundColor: AppTheme.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
}
