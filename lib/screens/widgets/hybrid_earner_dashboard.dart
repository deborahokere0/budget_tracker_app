import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';

class HybridEarnerDashboard extends StatefulWidget {
  final UserModel user;
  final Map<String, dynamic> stats;
  final VoidCallback onRefresh;

  const HybridEarnerDashboard({
    super.key,
    required this.user,
    required this.stats,
    required this.onRefresh,
  });

  @override
  State<HybridEarnerDashboard> createState() => _HybridEarnerDashboardState();
}

class _HybridEarnerDashboardState extends State<HybridEarnerDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  String _selectedTab = 'COMBINED';

  @override
  Widget build(BuildContext context) {
    final netAmount = widget.stats['netAmount'] ?? 0.0;
    final totalIncome = widget.stats['totalIncome'] ?? 0.0;
    final totalExpenses = widget.stats['totalExpenses'] ?? 0.0;

    // Simulated data - in real app, this would be calculated from transactions
    final salaryIncome = 350000.0;
    final gigIncome = 88100.0;
    final combinedIncome = salaryIncome + gigIncome;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => widget.onRefresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transactions',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tab Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton('SALARY', _selectedTab == 'SALARY'),
                          _buildTabButton('GIGS', _selectedTab == 'GIGS'),
                          _buildTabButton('COMBINED', _selectedTab == 'COMBINED'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // White content area
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            Icon(Icons.filter_list, color: Colors.grey[600]),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Cross-Funding Journal
                      if (_selectedTab == 'COMBINED')
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primaryBlue, AppTheme.darkBlue],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.flash_on, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cross-Funding Journal',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Used ₦62,000 gig income for water bill',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Transaction Stream
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TRANSACTIONS STREAM',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Salary',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Gigs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Transactions List
                      _buildTransactionsList(),

                      const SizedBox(height: 24),

                      // Rule Audit
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.settings, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(
                                      'RULE AUDIT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {},
                                  child: Text(
                                    'See All >',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Last Income ×',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: AppTheme.green, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Rule Applied: Upwork Gig',
                                  style: TextStyle(color: AppTheme.green),
                                ),
                              ],
                            ),
                            Text(
                              'TOTAL AMOUNT: ₦26,000',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '• DEBT: 50% ',
                                  style: TextStyle(color: Colors.red),
                                ),
                                Text(
                                  '• RECREATION: 20% ',
                                  style: TextStyle(color: Colors.orange),
                                ),
                                Text(
                                  '• SAVINGS: 30%',
                                  style: TextStyle(color: AppTheme.green),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Synergy Spotlight
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Synergy Spotlight',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gigs covered 68% of Birthday fund!',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        '₦137K/₦200K',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                CircularProgressIndicator(
                                  value: 0.68,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tax Forecast
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.orange),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: AppTheme.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tax Forecast',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.orange,
                                    ),
                                  ),
                                  Text(
                                    'ESTIMATED TAXES FOR Q1: ₦138,600.00',
                                    style: TextStyle(
                                      color: AppTheme.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Export Button
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Export Transactions (CSV)'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = text),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryBlue : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    final transactions = [
      {'date': 'Jun 8', 'desc': '₦100K for Rent', 'type': 'salary', 'icon': Icons.arrow_upward},
      {'date': 'Jun 10', 'desc': '₦42K from Fiverr', 'type': 'gig', 'icon': Icons.arrow_downward},
      {'date': 'Jun 10', 'desc': '₦15K from Uber', 'type': 'gig', 'icon': Icons.arrow_downward},
      {'date': 'Jun 10', 'desc': '₦15K for Cable TV', 'type': 'expense', 'icon': Icons.arrow_downward},
      {'date': 'Jun 10', 'desc': '₦12K for Cinema', 'type': 'expense', 'icon': Icons.arrow_downward},
    ];

    return Column(
      children: transactions.map((transaction) {
        final isSalary = transaction['type'] == 'salary';
        final isGig = transaction['type'] == 'gig';
        final bgColor = isSalary ? Colors.blue[50] : (isGig ? Colors.orange[50] : Colors.white);
        final iconColor = isSalary ? AppTheme.primaryBlue : (isGig ? AppTheme.orange : AppTheme.red);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(
                transaction['icon'] as IconData,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction['date'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      transaction['desc'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (transaction == transactions.last)
                TextButton(
                  onPressed: () {},
                  child: Text('+2 more'),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}