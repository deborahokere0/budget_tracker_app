import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../transactions/add_transaction_screen.dart';
import '../widgets/alert_banner.dart';

class HybridEarnerDashboard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRefresh;
  final FirebaseService _firebaseService = FirebaseService();

  HybridEarnerDashboard({
    super.key,
    required this.user,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _getStatsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final stats = snapshot.data ?? {
              'totalBalance': 0.0,
              'salaryIncome': 0.0,
              'gigIncome': 0.0,
              'totalSavings': 0.0,
            };

            final totalBalance = stats['totalBalance'] ?? 0.0;
            final salaryIncome = stats['salaryIncome'] ?? 0.0;
            final gigIncome = stats['gigIncome'] ?? 0.0;
            final totalSavings = stats['totalSavings'] ?? 0.0;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryBlue, AppTheme.darkBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Home',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Total Balance Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B5BA6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Balance',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      CurrencyFormatter.format(totalBalance),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // Pie Chart Indicator
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white24,
                                    ),
                                    child: Center(
                                      child: CustomPaint(
                                        size: const Size(60, 60),
                                        painter: PieChartPainter(
                                          salaryIncome,
                                          gigIncome,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Salary',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(salaryIncome),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Gigs',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(gigIncome),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  AlertBannersContainer(userId: user.uid),

                  // Content Area
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Budget Cards Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildBudgetCard(
                                  'Salary Budget',
                                  const Color(0xFFB8E6D5),
                                  [
                                    {'icon': '🏠', 'name': 'Rent', 'spent': 50000, 'budget': 50000},
                                    {'icon': '🛒', 'name': 'Groceries', 'spent': 52000, 'budget': 50000},
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildBudgetCard(
                                  'Gigs Budget',
                                  const Color(0xFFD4C5F9),
                                  [
                                    {'icon': '🎭', 'name': 'Recreation', 'spent': 38000, 'budget': 35000},
                                    {'icon': '📺', 'name': 'Cable TV', 'spent': 15000, 'budget': 15000},
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Piggy Bank Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2B5BA6), Color(0xFF1E3A6D)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Savings',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        CurrencyFormatter.format(totalSavings),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.green,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${((salaryIncome / (salaryIncome + gigIncome)) * 100).toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.purple[300],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${((gigIncome / (salaryIncome + gigIncome)) * 100).toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () {},
                                        child: const Text(
                                          'View More >',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Icon(
                                    Icons.savings,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          _buildActionButtons(context, onRefresh)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Stream<Map<String, dynamic>> _getStatsStream() {
    return _firebaseService.getTransactions().asyncMap((transactions) async {
      double totalIncome = 0;
      double totalExpenses = 0;
      double salaryIncome = 0;
      double gigIncome = 0;
      double totalSavings = 0;

      for (var transaction in transactions) {
        if (transaction.type == 'income') {
          totalIncome += transaction.amount;

          if (transaction.source?.toLowerCase() == 'salary' ||
              transaction.category.toLowerCase() == 'salary') {
            salaryIncome += transaction.amount;
          } else {
            gigIncome += transaction.amount;
          }
        } else if (transaction.type == 'expense') {
          totalExpenses += transaction.actualExpenseAmount;

          if (transaction.hasSavingsAllocation) {
            totalSavings += transaction.savingsAllocation!;
          }
        }
      }

      return {
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'totalBalance': totalIncome - totalExpenses,
        'salaryIncome': salaryIncome,
        'gigIncome': gigIncome,
        'totalSavings': totalSavings,
      };
    });
  }

  Widget _buildBudgetCard(
      String title,
      Color bgColor,
      List<Map<String, dynamic>> items,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 12),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            final isOverBudget = item['spent'] > item['budget'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    item['icon'],
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${CurrencyFormatter.format(item['spent'])}/${CurrencyFormatter.format(item['budget'])}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isOverBudget ? AppTheme.red : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

Widget _buildActionButtons(BuildContext context, VoidCallback onRefresh) {
  return Row(
    children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionScreen(
                  onTransactionAdded: onRefresh,
                  initialTransactionType: 'income',
                ),
              ),
            );
          },
          icon: const Icon(Icons.arrow_downward),
          label: const Text('Add Income'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionScreen(
                  onTransactionAdded: onRefresh,
                  initialTransactionType: 'expense',
                ),
              ),
            );
          },
          icon: const Icon(Icons.arrow_upward),
          label: const Text('Add Expense'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    ],
  );
}

// Custom Pie Chart Painter
class PieChartPainter extends CustomPainter {
  final double salary;
  final double gigs;

  PieChartPainter(this.salary, this.gigs);

  @override
  void paint(Canvas canvas, Size size) {
    final total = salary + gigs;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Salary portion (blue)
    final salaryPaint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..style = PaintingStyle.fill;

    final salaryAngle = (salary / total) * 360 * (3.14159 / 180);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * (3.14159 / 180),
      salaryAngle,
      true,
      salaryPaint,
    );

    // Gigs portion (purple)
    final gigsPaint = Paint()
      ..color = const Color(0xFFB794F4)
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * (3.14159 / 180) + salaryAngle,
      (gigs / total) * 360 * (3.14159 / 180),
      true,
      gigsPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}