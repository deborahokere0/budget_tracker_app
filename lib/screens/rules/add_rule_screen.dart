import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/rule_model.dart';
import '../../theme/app_theme.dart';

class AddRuleScreen extends StatefulWidget {
  final String ruleType;

  const AddRuleScreen({
    super.key,
    required this.ruleType,
  });

  @override
  State<AddRuleScreen> createState() => _AddRuleScreenState();
}

class _AddRuleScreenState extends State<AddRuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  String _selectedCategory = 'Food';
  String _selectedCondition = 'income';
  double _allocationPercent = 10.0;
  int _priority = 1;
  bool _isActive = true;
  bool _isLoading = false;

  final List<String> _categories = [
    'Food', 'Transport', 'Data', 'Entertainment',
    'Utilities', 'Savings', 'Emergency', 'Other'
  ];

  Future<void> _saveRule() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      Map<String, dynamic> conditions = {};
      Map<String, dynamic> actions = {};

      // Build conditions based on rule type
      switch (widget.ruleType) {
        case 'allocation':
          conditions['transactionType'] = 'income';
          conditions['minAmount'] = double.tryParse(_amountController.text) ?? 0;
          actions['allocateToSavings'] = _allocationPercent;
          break;
        case 'savings':
          conditions['category'] = _selectedCategory;
          actions['savePercent'] = _allocationPercent;
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
        id: '',
        userId: _firebaseService.currentUserId!,
        name: _nameController.text,
        type: widget.ruleType,
        conditions: conditions,
        actions: actions,
        priority: _priority,
        isActive: _isActive,
        createdAt: DateTime.now(),
      );

      await _firebaseService.addRule(rule);
      setState(() => _isLoading = false);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rule created successfully'),
          backgroundColor: AppTheme.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Add ${_getRuleTypeTitle()} Rule'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
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
                decoration: InputDecoration(
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
                    style: TextStyle(
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
                title: Text('Active'),
                subtitle: Text('Rule will be applied automatically'),
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
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                  'Save Rule',
                  style: TextStyle(fontSize: 16),
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
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
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
                  style: TextStyle(fontSize: 16),
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
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save Percentage: ${_allocationPercent.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 16),
                ),
                Slider(
                  value: _allocationPercent,
                  min: 5,
                  max: 30,
                  divisions: 5,
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

      case 'alert':
        return Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
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
              decoration: InputDecoration(
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
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.orange.withOpacity(0.1),
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
                Text(
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
        return Container();
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

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}