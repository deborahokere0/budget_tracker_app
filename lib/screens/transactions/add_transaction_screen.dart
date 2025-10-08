// lib/screens/transactions/add_transaction_screen.dart
import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  final VoidCallback onTransactionAdded;

  const AddTransactionScreen({
    super.key,
    required this.onTransactionAdded,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  String _transactionType = 'expense';
  String _selectedCategory = 'Food';
  String? _incomeSource;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<String> _expenseCategories = [
    'Food', 'Transport', 'Data', 'Entertainment', 'Utilities',
    'Groceries', 'Health', 'Education', 'Savings', 'Other'
  ];

  final List<String> _incomeCategories = [
    'Salary', 'Freelance', 'Gig', 'Investment', 'Gift', 'Other'
  ];

  final List<String> _incomeSources = [
    'Fiverr', 'Upwork', 'Uber', 'Company', 'Client', 'Other'
  ];

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final transaction = TransactionModel(
        id: '',
        userId: _firebaseService.currentUserId!,
        type: _transactionType,
        category: _selectedCategory,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
        date: _selectedDate,
        source: _incomeSource,
      );

      await _firebaseService.addTransaction(transaction);

      setState(() => _isLoading = false);

      widget.onTransactionAdded();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction added successfully'),
          backgroundColor: AppTheme.green,
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction Type Toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _transactionType = 'income'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _transactionType == 'income'
                                ? AppTheme.green
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Income',
                              style: TextStyle(
                                color: _transactionType == 'income'
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _transactionType = 'expense'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _transactionType == 'expense'
                                ? AppTheme.red
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Expense',
                              style: TextStyle(
                                color: _transactionType == 'expense'
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₦ ',
                  prefixStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Amount is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Category Selection
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: (_transactionType == 'income'
                    ? _incomeCategories
                    : _expenseCategories)
                    .map((category) => DropdownMenuItem(
                  value: category,
                  child: Text(category),
                ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value!),
              ),

              const SizedBox(height: 24),

              // Income Source (for income only)
              if (_transactionType == 'income')
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _incomeSource,
                      decoration: const InputDecoration(
                        labelText: 'Source',
                        prefixIcon: Icon(Icons.source),
                      ),
                      items: _incomeSources
                          .map((source) => DropdownMenuItem(
                        value: source,
                        child: Text(source),
                      ))
                          .toList(),
                      onChanged: (value) => setState(() => _incomeSource = value),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                  hintText: 'Enter transaction details',
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Date Selection
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _transactionType == 'income'
                      ? AppTheme.green
                      : AppTheme.red,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  'Add ${_transactionType == 'income' ? 'Income' : 'Expense'}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}