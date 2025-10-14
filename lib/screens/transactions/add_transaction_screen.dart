import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firebase_service.dart';
import '../../models/transaction_model.dart';
import '../../models/rule_model.dart';
import '../../theme/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  final VoidCallback onTransactionAdded;
  final String? initialTransactionType;

  const AddTransactionScreen({
    super.key,
    required this.onTransactionAdded,
    this.initialTransactionType,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sourceController = TextEditingController();
  final _savingsAmountController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  String _transactionType = 'expense';
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _saveToSavings = false;
  String? _selectedSavingsRule;
  List<RuleModel> _savingsRules = [];

  final List<String> _expenseCategories = [
    'Food',
    'Transport',
    'Data',
    'Entertainment',
    'Utilities',
    'Healthcare',
    'Education',
    'Shopping',
    'Other',
  ];

  final List<String> _incomeCategories = [
    'Salary',
    'Freelance',
    'Gig Work',
    'Investment',
    'Gift',
    'Other',
  ];

  List<String> get _currentCategories =>
      _transactionType == 'income' ? _incomeCategories : _expenseCategories;

  @override
  void initState() {
    super.initState();
    if (widget.initialTransactionType != null) {
      _transactionType = widget.initialTransactionType!;
    }
    _selectedCategory = _currentCategories.first;
    _loadSavingsRules();
  }

  Future<void> _loadSavingsRules() async {
    try {
      final rules = await _firebaseService.getRules().first;
      setState(() {
        _savingsRules = rules.where((r) => r.type == 'savings' && r.isActive).toList();
      });
    } catch (e) {
      print('Error loading savings rules: $e');
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate savings amount if enabled
    if (_saveToSavings) {
      if (_selectedSavingsRule == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a savings goal'),
            backgroundColor: AppTheme.red,
          ),
        );
        return;
      }
      if (_savingsAmountController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter savings amount'),
            backgroundColor: AppTheme.red,
          ),
        );
        return;
      }

      final savingsAmount = double.tryParse(_savingsAmountController.text);
      final totalAmount = double.tryParse(_amountController.text);

      if (savingsAmount != null && totalAmount != null && savingsAmount > totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Savings amount cannot exceed total amount'),
            backgroundColor: AppTheme.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final description = _descriptionController.text.trim();
      final source = _transactionType == 'income' && _sourceController.text.isNotEmpty
          ? _sourceController.text.trim()
          : null;

      // Get savings details if enabled
      double? savingsAllocation;
      String? savingsGoalId;
      String? savingsGoalName;

      if (_saveToSavings && _selectedSavingsRule != null) {
        savingsAllocation = double.parse(_savingsAmountController.text);
        final selectedRule = _savingsRules.firstWhere((r) => r.id == _selectedSavingsRule);
        savingsGoalId = selectedRule.id;
        savingsGoalName = selectedRule.isPiggyBank == true
            ? 'Piggybank'
            : (selectedRule.goalName ?? 'Savings');
      }

      // Create single transaction with savings allocation
      final transaction = TransactionModel(
        id: '',
        userId: _firebaseService.currentUserId!,
        type: _transactionType,
        category: _selectedCategory,
        amount: amount,
        description: description,
        date: _selectedDate,
        source: source,
        savingsAllocation: savingsAllocation,
        savingsGoalId: savingsGoalId,
        savingsGoalName: savingsGoalName,
      );

      await _firebaseService.addTransaction(transaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_saveToSavings
                ? 'Transaction added with ₦${savingsAllocation!.toStringAsFixed(0)} saved!'
                : 'Transaction added successfully!'),
            backgroundColor: AppTheme.green,
          ),
        );
        widget.onTransactionAdded();
        Navigator.pop(context);
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    _savingsAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Transaction'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction Type Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _transactionType = 'income';
                            _selectedCategory = _incomeCategories.first;
                            _saveToSavings = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _transactionType == 'income'
                                ? AppTheme.green
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'INCOME',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _transactionType == 'income'
                                  ? Colors.white
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _transactionType = 'expense';
                            _selectedCategory = _expenseCategories.first;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _transactionType == 'expense'
                                ? AppTheme.red
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'EXPENSE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _transactionType == 'expense'
                                  ? Colors.white
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount (₦)',
                  prefixIcon: const Icon(Icons.money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _currentCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),

              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Date Picker
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 12),
                      Text(
                        'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Source Field (Income Only)
              if (_transactionType == 'income')
                TextFormField(
                  controller: _sourceController,
                  decoration: InputDecoration(
                    labelText: 'Source (Optional)',
                    hintText: 'e.g., Salary, Upwork, Uber',
                    prefixIcon: const Icon(Icons.source),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

              // Save to Savings Section (Expense Only)
              if (_transactionType == 'expense' && _savingsRules.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.savings, color: AppTheme.green),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Save to Savings Goal',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Switch(
                            value: _saveToSavings,
                            activeThumbColor: AppTheme.green,
                            onChanged: (value) {
                              setState(() => _saveToSavings = value);
                            },
                          ),
                        ],
                      ),
                      if (_saveToSavings) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSavingsRule,
                          decoration: InputDecoration(
                            labelText: 'Select Savings Goal',
                            prefixIcon: const Icon(Icons.flag),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _savingsRules.map((rule) {
                            final label = rule.isPiggyBank == true
                                ? '🐷 Piggybank'
                                : '${rule.goalName} (${rule.savingsProgress.toStringAsFixed(0)}%)';
                            return DropdownMenuItem(
                              value: rule.id,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedSavingsRule = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _savingsAmountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Amount to Save (₦)',
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            helperText: 'Part of the total amount above',
                            helperStyle: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _transactionType == 'income'
                        ? AppTheme.green
                        : AppTheme.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'ADD ${_transactionType.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}