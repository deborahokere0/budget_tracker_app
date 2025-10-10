import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import 'add_transaction_screen.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _filterType = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _filterTransactions(List<TransactionModel> transactions) {
    var filtered = transactions;

    if (_filterType != 'all') {
      filtered = filtered.where((t) => t.type == _filterType).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        final query = _searchQuery.toLowerCase();
        return t.description.toLowerCase().contains(query) ||
            t.category.toLowerCase().contains(query) ||
            (t.source?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this transaction?\n\n'
              '${transaction.description}\n'
              '${CurrencyFormatter.format(transaction.amount)}',
        ),
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
        await _firebaseService.deleteTransaction(transaction.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction deleted successfully'),
              backgroundColor: AppTheme.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting transaction: $e'),
              backgroundColor: AppTheme.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(
                    onTransactionAdded: () {},
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            color: AppTheme.primaryBlue,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Income', 'income'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Expense', 'expense'),
                  ],
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: StreamBuilder<List<TransactionModel>>(
              stream: _firebaseService.getTransactions(),
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
                          'Error loading transactions',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red[600]),
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
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first transaction',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final filteredTransactions = _filterTransactions(snapshot.data!);

                if (filteredTransactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No matching transactions',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group transactions by date
                final groupedTransactions = <String, List<TransactionModel>>{};
                for (var transaction in filteredTransactions) {
                  final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
                  if (!groupedTransactions.containsKey(dateKey)) {
                    groupedTransactions[dateKey] = [];
                  }
                  groupedTransactions[dateKey]!.add(transaction);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupedTransactions.length,
                  itemBuilder: (context, index) {
                    final dateKey = groupedTransactions.keys.elementAt(index);
                    final transactions = groupedTransactions[dateKey]!;
                    final date = DateTime.parse(dateKey);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _formatDateHeader(date),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        ...transactions.map((transaction) =>
                            _buildTransactionCard(transaction)),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterType = value);
      },
      backgroundColor: Colors.white.withValues(alpha:0.2),
      selectedColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryBlue : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    final isIncome = transaction.type == 'income';
    final color = isIncome ? AppTheme.green : AppTheme.red;
    final icon = isIncome ? Icons.arrow_downward : Icons.arrow_upward;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Dismissible(
        key: Key(transaction.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
          ),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Transaction'),
              content: const Text('Are you sure you want to delete this transaction?'),
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
        },
        onDismissed: (direction) {
          _firebaseService.deleteTransaction(transaction.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction deleted'),
              backgroundColor: AppTheme.green,
            ),
          );
        },
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            transaction.description,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(transaction.category),
              if (transaction.source != null)
                Text(
                  'Source: ${transaction.source}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}${CurrencyFormatter.format(transaction.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          onLongPress: () => _deleteTransaction(transaction),
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM d, yyyy').format(date);
    }
  }
}