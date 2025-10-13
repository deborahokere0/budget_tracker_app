import 'package:flutter/material.dart';
import '../../models/rule_model.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';

class AlertBanner extends StatefulWidget {
  final RuleModel alertRule;
  final double currentSpending;
  final VoidCallback onDismiss;

  const AlertBanner({
    super.key,
    required this.alertRule,
    required this.currentSpending,
    required this.onDismiss,
  });

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final threshold = widget.alertRule.conditions['threshold'] ?? 0.0;
    final category = widget.alertRule.conditions['category'] ?? 'Unknown';
    final isTriggered = widget.currentSpending >= threshold;

    if (!isTriggered) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.orange),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.alertRule.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$category spending: ${CurrencyFormatter.format(widget.currentSpending)} / ${CurrencyFormatter.format(threshold)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'You\'ve exceeded your threshold by ${CurrencyFormatter.format(widget.currentSpending - threshold)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() => _isDismissed = true);
              widget.onDismiss();
            },
          ),
        ],
      ),
    );
  }
}

// Widget to show all active alerts
class AlertBannersContainer extends StatelessWidget {
  final String userId;

  const AlertBannersContainer({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RuleModel>>(
      stream: FirebaseService().getRules(),
      builder: (context, rulesSnapshot) {
        if (!rulesSnapshot.hasData) return const SizedBox.shrink();

        final alertRules = rulesSnapshot.data!
            .where((r) => r.type == 'alert' && r.isActive)
            .toList();

        if (alertRules.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<Map<String, double>>(
          stream: FirebaseService().getCategorySpending(userId),
          builder: (context, spendingSnapshot) {
            if (!spendingSnapshot.hasData) return const SizedBox.shrink();

            final categorySpending = spendingSnapshot.data!;
            final triggeredAlerts = <Widget>[];

            for (var rule in alertRules) {
              final category = rule.conditions['category'] ?? '';
              final currentSpending = categorySpending[category] ?? 0.0;

              triggeredAlerts.add(
                AlertBanner(
                  alertRule: rule,
                  currentSpending: currentSpending,
                  onDismiss: () {
                    // Could save dismissal state to preferences
                  },
                ),
              );
            }

            if (triggeredAlerts.isEmpty) return const SizedBox.shrink();

            return Column(children: triggeredAlerts);
          },
        );
      },
    );
  }
}