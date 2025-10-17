import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/rule_model.dart';
import '../../services/alert_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';

class EnhancedAlertBanner extends StatefulWidget {
  final RuleModel alertRule;
  final double currentSpending;
  final double exceeded;
  final VoidCallback? onDismiss;

  const EnhancedAlertBanner({
    super.key,
    required this.alertRule,
    required this.currentSpending,
    required this.exceeded,
    this.onDismiss,
  });

  @override
  State<EnhancedAlertBanner> createState() => _EnhancedAlertBannerState();
}

class _EnhancedAlertBannerState extends State<EnhancedAlertBanner>
    with SingleTickerProviderStateMixin {
  bool _isDismissed = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _checkIfDismissed();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(EnhancedAlertBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check dismissal status if alert rule changed
    if (oldWidget.alertRule.id != widget.alertRule.id) {
      _checkIfDismissed();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkIfDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedKey = 'alert_dismissed_${widget.alertRule.id}';
    final dismissedUntil = prefs.getString(dismissedKey);

    if (dismissedUntil != null) {
      final dismissTime = DateTime.parse(dismissedUntil);
      if (DateTime.now().isBefore(dismissTime)) {
        if (mounted) {
          setState(() => _isDismissed = true);
        }
      } else {
        // Clean up expired dismissal
        await prefs.remove(dismissedKey);
      }
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedKey = 'alert_dismissed_${widget.alertRule.id}';

    // Dismiss for 24 hours
    final dismissUntil = DateTime.now().add(const Duration(hours: 24));
    await prefs.setString(dismissedKey, dismissUntil.toIso8601String());

    await _animationController.reverse();
    if (mounted) {
      setState(() => _isDismissed = true);
    }
    widget.onDismiss?.call();
  }

  Color _getSeverityColor() {
    final threshold = widget.alertRule.conditions['threshold'] ?? 0.0;
    final percentOver = (widget.exceeded / threshold) * 100;

    if (percentOver > 50) return AppTheme.red;
    if (percentOver > 25) return AppTheme.orange;
    return Colors.amber;
  }

  IconData _getSeverityIcon() {
    final threshold = widget.alertRule.conditions['threshold'] ?? 0.0;
    final percentOver = (widget.exceeded / threshold) * 100;

    if (percentOver > 50) return Icons.error;
    if (percentOver > 25) return Icons.warning_amber_rounded;
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final threshold = widget.alertRule.conditions['threshold'] ?? 0.0;
    final category = widget.alertRule.conditions['category'] ?? 'Unknown';
    final color = _getSeverityColor();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showAlertDetails(context, category, threshold),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getSeverityIcon(),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.alertRule.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ALERT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$category: ${CurrencyFormatter.format(widget.currentSpending)} / ${CurrencyFormatter.format(threshold)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.trending_up, size: 14, color: color),
                              const SizedBox(width: 4),
                              Text(
                                'Exceeded by ${CurrencyFormatter.format(widget.exceeded)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _dismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAlertDetails(BuildContext context, String category, double threshold) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(_getSeverityIcon(), color: _getSeverityColor(), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.alertRule.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailCard(
                  'Current Spending',
                  CurrencyFormatter.format(widget.currentSpending),
                  Icons.shopping_cart,
                  _getSeverityColor(),
                ),
                const SizedBox(height: 12),
                _buildDetailCard(
                  'Budget Threshold',
                  CurrencyFormatter.format(threshold),
                  Icons.flag,
                  AppTheme.primaryBlue,
                ),
                const SizedBox(height: 12),
                _buildDetailCard(
                  'Amount Over Budget',
                  CurrencyFormatter.format(widget.exceeded),
                  Icons.trending_up,
                  AppTheme.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'What to do:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSuggestion('Review your recent $category expenses', Icons.search),
                _buildSuggestion('Consider adjusting your budget or spending habits', Icons.edit),
                _buildSuggestion('Set up a savings rule to prevent overspending', Icons.savings),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _dismiss();
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Got it'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Rule'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestion(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[700]))),
        ],
      ),
    );
  }
}

// Enhanced container with key to force rebuild
class EnhancedAlertBannersContainer extends StatelessWidget {
  final String userId;
  final String? dashboardType; // Add to force refresh on type change

  const EnhancedAlertBannersContainer({
    super.key,
    required this.userId,
    this.dashboardType,
  });

  @override
  Widget build(BuildContext context) {
    final alertService = AlertService(userId);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: alertService.getTriggeredAlertsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final triggeredAlerts = snapshot.data!;
        triggeredAlerts.sort((a, b) {
          final exceededA = a['exceeded'] as double;
          final exceededB = b['exceeded'] as double;
          return exceededB.compareTo(exceededA);
        });

        return Column(
          key: ValueKey('alerts_${userId}_${dashboardType}_${triggeredAlerts.length}'),
          children: triggeredAlerts.map((alertData) {
            return EnhancedAlertBanner(
              key: ValueKey(alertData['rule'].id),
              alertRule: alertData['rule'] as RuleModel,
              currentSpending: alertData['currentSpending'] as double,
              exceeded: alertData['exceeded'] as double,
            );
          }).toList(),
        );
      },
    );
  }
}

class GlobalAlertOverlay extends StatelessWidget {
  final String userId;
  final Widget child;
  final String? dashboardType;

  const GlobalAlertOverlay({
    super.key,
    required this.userId,
    required this.child,
    this.dashboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: EnhancedAlertBannersContainer(
              userId: userId,
              dashboardType: dashboardType,
            ),
          ),
        ),
      ],
    );
  }
}