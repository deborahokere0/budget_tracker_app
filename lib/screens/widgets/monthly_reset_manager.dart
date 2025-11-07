import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/rule_model.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';

class MonthlyResetManager extends StatefulWidget {
  final String userId;
  final VoidCallback? onAlertsEnabled;

  const MonthlyResetManager({
    Key? key,
    required this.userId,
    this.onAlertsEnabled,
  }) : super(key: key);

  @override
  State<MonthlyResetManager> createState() => _MonthlyResetManagerState();
}

class _MonthlyResetManagerState extends State<MonthlyResetManager> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  Map<String, bool> _selectedAlerts = {};
  bool _autoEnableNextMonth = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rules')
          .doc(widget.userId)
          .collection('userRules')
          .where('type', isEqualTo: 'alert')
          .where('isActive', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final disabledAlerts = snapshot.data!.docs
            .map((doc) => RuleModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Monthly Reset - Alert Rules Disabled',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      // Optionally dismiss this notification
                      // You might want to save a preference to not show again
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Your alert rules have been disabled for the new month. '
                'Review and re-enable the ones you want to keep active.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 16),
              
              // Quick actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Enable All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.green,
                        side: BorderSide(color: AppTheme.green),
                      ),
                      onPressed: _isLoading ? null : _enableAllAlerts,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('Custom'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                        side: BorderSide(color: AppTheme.primaryBlue),
                      ),
                      onPressed: _isLoading ? null : () => _showCustomEnableDialog(disabledAlerts),
                    ),
                  ),
                ],
              ),
              
              // Show disabled alerts count
              const SizedBox(height: 8),
              Text(
                '${disabledAlerts.length} alert${disabledAlerts.length != 1 ? 's' : ''} disabled',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _enableAllAlerts() async {
    setState(() => _isLoading = true);
    
    try {
      await _firebaseService.enableAllAlertRules();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ All alert rules have been enabled'),
          backgroundColor: AppTheme.green,
        ),
      );
      
      widget.onAlertsEnabled?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enabling alerts: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCustomEnableDialog(List<RuleModel> disabledAlerts) {
    // Initialize selection state
    _selectedAlerts = {
      for (var alert in disabledAlerts) alert.id: false,
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Alerts to Enable'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Select all checkbox
                    CheckboxListTile(
                      title: const Text(
                        'Select All',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: _selectedAlerts.values.every((v) => v),
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedAlerts.updateAll((key, _) => value ?? false);
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const Divider(),
                    // Alert list
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: disabledAlerts.map((alert) {
                            final category = alert.conditions['category'] ?? 'Unknown';
                            final thresholdType = alert.conditions['thresholdType'] ?? 'amount';
                            final thresholdValue = alert.conditions['thresholdValue'] ?? 0.0;
                            
                            return CheckboxListTile(
                              title: Text(alert.name),
                              subtitle: Text(
                                '$category - ${thresholdType == 'percentage' 
                                  ? '${thresholdValue}%' 
                                  : '\$${thresholdValue.toStringAsFixed(2)}'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              value: _selectedAlerts[alert.id] ?? false,
                              onChanged: (value) {
                                setDialogState(() {
                                  _selectedAlerts[alert.id] = value ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const Divider(),
                    // Auto-enable preference
                    CheckboxListTile(
                      title: const Text('Auto-enable these alerts next month'),
                      subtitle: const Text(
                        'Selected alerts will automatically activate at month start',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _autoEnableNextMonth,
                      onChanged: (value) {
                        setDialogState(() {
                          _autoEnableNextMonth = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _selectedAlerts.values.any((v) => v)
                      ? () {
                          Navigator.of(context).pop();
                          _enableSelectedAlerts(disabledAlerts);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                  ),
                  child: Text(
                    'Enable ${_selectedAlerts.values.where((v) => v).length} Alert(s)',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _enableSelectedAlerts(List<RuleModel> disabledAlerts) async {
    setState(() => _isLoading = true);
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      int enabledCount = 0;

      for (var alert in disabledAlerts) {
        if (_selectedAlerts[alert.id] == true) {
          final docRef = FirebaseFirestore.instance
              .collection('rules')
              .doc(widget.userId)
              .collection('userRules')
              .doc(alert.id);

          final updates = {
            'isActive': true,
          };

          // If auto-enable preference is set, update the rule
          if (_autoEnableNextMonth) {
            updates['conditions'] = {
              ...alert.conditions,
              'autoEnableMonthly': true,
            } as bool;
          }

          batch.update(docRef, updates);
          enabledCount++;
        }
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Enabled $enabledCount alert rule${enabledCount != 1 ? 's' : ''}'),
          backgroundColor: AppTheme.green,
        ),
      );
      
      widget.onAlertsEnabled?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enabling selected alerts: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

/// Widget to show spending trends from archived data
class SpendingTrendsWidget extends StatelessWidget {
  final String userId;
  final String category;
  final int monthsToShow;

  const SpendingTrendsWidget({
    Key? key,
    required this.userId,
    required this.category,
    this.monthsToShow = 6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();

    return FutureBuilder<Map<String, List<double>>>(
      future: firebaseService.getSpendingTrends(monthsBack: monthsToShow),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data![category] == null) {
          return const SizedBox.shrink();
        }

        final trends = snapshot.data![category]!;
        if (trends.isEmpty) return const SizedBox.shrink();

        final maxSpending = trends.reduce((a, b) => a > b ? a : b);
        final avgSpending = trends.reduce((a, b) => a + b) / trends.length;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historical Spending Trend',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _TrendLinePainter(
                    values: trends,
                    maxValue: maxSpending,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Avg: \$${avgSpending.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  Text(
                    'Max: \$${maxSpending.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final Color color;

  _TrendLinePainter({
    required this.values,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || maxValue == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (values.length - 1);
    
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxValue * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxValue * size.height);
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}