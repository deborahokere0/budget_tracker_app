import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/rule_model.dart';
import '../../services/alert_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/data_validator.dart';

class EnhancedAlertBanner extends StatefulWidget {
  final RuleModel alertRule;
  final double currentSpending;
  final double budgetAmount;
  final double thresholdAmount;
  final VoidCallback? onDismiss;

  const EnhancedAlertBanner({
    super.key,
    required this.alertRule,
    required this.currentSpending,
    required this.budgetAmount,
    required this.thresholdAmount,
    this.onDismiss,
  });

  @override
  State<EnhancedAlertBanner> createState() => _EnhancedAlertBannerState();
}

class _EnhancedAlertBannerState extends State<EnhancedAlertBanner>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isDismissed = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Platform detection
  bool get isWebPlatform => kIsWeb;
  bool get isMobilePlatform => !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  bool get isDesktopPlatform => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  bool get wantKeepAlive => true; // Maintain state when scrolling

  @override
  void initState() {
    super.initState();
    _checkIfDismissed();

    // Platform-specific animation duration
    _animationController = AnimationController(
      duration: Duration(milliseconds: isWebPlatform ? 0 : 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    if (isWebPlatform) {
      _animationController.value = 1.0;
    } else {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(EnhancedAlertBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alertRule.id != widget.alertRule.id) {
      _checkIfDismissed();
      if (!isWebPlatform) {
        _animationController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkIfDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedKey = 'alert_dismissed_${widget.alertRule.id}';
      final dismissedUntil = prefs.getString(dismissedKey);

      if (dismissedUntil != null) {
        final dismissTime = DateTime.tryParse(dismissedUntil);
        if (dismissTime != null && DateTime.now().isBefore(dismissTime)) {
          if (mounted) {
            setState(() => _isDismissed = true);
          }
        } else {
          await prefs.remove(dismissedKey);
        }
      }
    } catch (e) {
      debugPrint('Error checking dismissed state: $e');
    }
  }

  Future<void> _dismissWithDuration(Duration duration, String durationLabel) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedKey = 'alert_dismissed_${widget.alertRule.id}';

      final dismissUntil = DateTime.now().add(duration);
      await prefs.setString(dismissedKey, dismissUntil.toIso8601String());

      // Save to Firebase for cross-device sync (optional)
      await _saveAlertHistory('dismissed', durationLabel);

      if (mounted) {
        await _animationController.reverse();
        setState(() => _isDismissed = true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Alert snoozed for $durationLabel'),
                  ),
                ],
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      widget.onDismiss?.call();
    } catch (e) {
      debugPrint('Error dismissing alert: $e');
    }
  }

  Future<void> _saveAlertHistory(String action, String details) async {
    // Save alert interaction history to Firebase
    try {
      // This would be implemented in the alert service
      debugPrint('Alert history: ${widget.alertRule.id} - $action - $details');
    } catch (e) {
      debugPrint('Error saving alert history: $e');
    }
  }

  double get exceeded => DataValidator.safeParseDouble(
    widget.currentSpending - widget.thresholdAmount,
    fallback: 0.0,
  );

  Color _getSeverityColor() {
    final percentOver = widget.budgetAmount > 0
        ? (exceeded / widget.budgetAmount) * 100
        : 0.0;

    if (percentOver > 50) return AppTheme.red;
    if (percentOver > 25) return AppTheme.orange;
    return Colors.amber[700]!;
  }

  IconData _getSeverityIcon() {
    final percentOver = widget.budgetAmount > 0
        ? (exceeded / widget.budgetAmount) * 100
        : 0.0;

    if (percentOver > 50) return Icons.error_rounded;
    if (percentOver > 25) return Icons.warning_amber_rounded;
    return Icons.info_rounded;
  }

  String _getSeverityLabel() {
    final percentOver = widget.budgetAmount > 0
        ? (exceeded / widget.budgetAmount) * 100
        : 0.0;

    if (percentOver > 50) return 'CRITICAL';
    if (percentOver > 25) return 'WARNING';
    return 'ALERT';
  }

  void _showSnoozeOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Snooze Alert',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('1 Hour'),
              onTap: () {
                Navigator.pop(context);
                _dismissWithDuration(const Duration(hours: 1), '1 hour');
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('4 Hours'),
              onTap: () {
                Navigator.pop(context);
                _dismissWithDuration(const Duration(hours: 4), '4 hours');
              },
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('1 Day'),
              onTap: () {
                Navigator.pop(context);
                _dismissWithDuration(const Duration(days: 1), '1 day');
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('1 Week'),
              onTap: () {
                Navigator.pop(context);
                _dismissWithDuration(const Duration(days: 7), '1 week');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isDismissed) return const SizedBox.shrink();

    final category = DataValidator.safeParseString(
      widget.alertRule.conditions['category'],
      fallback: 'Unknown',
    );
    final color = _getSeverityColor();
    final percentUsed = widget.budgetAmount > 0
        ? (widget.currentSpending / widget.budgetAmount * 100).clamp(0, 200)
        : 0.0;

    return Semantics(
      label: 'Budget alert for $category category',
      button: true,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: color, width: 5),
                top: BorderSide(color: Colors.grey[200]!, width: 1),
                right: BorderSide(color: Colors.grey[200]!, width: 1),
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showAlertDetails(context, category),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getSeverityIcon(),
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title with severity badge
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.alertRule.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getSeverityLabel(),
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Alert message
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                                children: [
                                  TextSpan(text: '$category spending '),
                                  TextSpan(
                                    text: CurrencyFormatter.format(widget.currentSpending),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                  const TextSpan(text: ' exceeded threshold '),
                                  TextSpan(
                                    text: CurrencyFormatter.format(widget.thresholdAmount),
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Progress bar
                            Stack(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  height: 6,
                                  width: MediaQuery.of(context).size.width *
                                      (percentUsed / 100) *
                                      0.5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: percentUsed > 100
                                          ? [AppTheme.red, AppTheme.orange]
                                          : [color, color.withOpacity(0.7)],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Exceeded amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Exceeded by ${CurrencyFormatter.format(exceeded)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${percentUsed.toStringAsFixed(0)}% of budget',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Action button
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'snooze') {
                            _showSnoozeOptions(context);
                          } else if (value == 'dismiss') {
                            _dismissWithDuration(const Duration(days: 1), '1 day');
                          } else if (value == 'details') {
                            _showAlertDetails(context, category);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'details',
                            child: ListTile(
                              leading: Icon(Icons.info_outline),
                              title: Text('View Details'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'snooze',
                            child: ListTile(
                              leading: Icon(Icons.snooze),
                              title: Text('Snooze Alert'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'dismiss',
                            child: ListTile(
                              leading: Icon(Icons.close),
                              title: Text('Dismiss'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAlertDetails(BuildContext context, String category) {
    final percentOver = widget.budgetAmount > 0
        ? (exceeded / widget.budgetAmount) * 100
        : 0.0;
    final percentUsed = widget.budgetAmount > 0
        ? (widget.currentSpending / widget.budgetAmount * 100).clamp(0, 200)
        : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      _getSeverityIcon(),
                      color: _getSeverityColor(),
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.alertRule.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Budget Alert for $category',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Key metrics - Responsive layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 400;

                    if (isNarrow) {
                      // Mobile: 2x2 grid
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactMetric(
                                  'Current',
                                  CurrencyFormatter.format(widget.currentSpending),
                                  '${percentUsed.toStringAsFixed(0)}%',
                                  _getSeverityColor(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCompactMetric(
                                  'Budget',
                                  CurrencyFormatter.format(widget.budgetAmount),
                                  'Total',
                                  AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactMetric(
                                  'Threshold',
                                  CurrencyFormatter.format(widget.thresholdAmount),
                                  '88% point',
                                  AppTheme.orange,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCompactMetric(
                                  'Over By',
                                  CurrencyFormatter.format(exceeded),
                                  '${percentOver.toStringAsFixed(0)}%',
                                  AppTheme.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    // Desktop: single row
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(child: _buildInlineMetric('Current', CurrencyFormatter.format(widget.currentSpending), '${percentUsed.toStringAsFixed(0)}%', _getSeverityColor())),
                            VerticalDivider(color: Colors.grey[300], thickness: 1, width: 1),
                            Expanded(child: _buildInlineMetric('Budget', CurrencyFormatter.format(widget.budgetAmount), 'Total', AppTheme.primaryBlue)),
                            VerticalDivider(color: Colors.grey[300], thickness: 1, width: 1),
                            Expanded(child: _buildInlineMetric('Threshold', CurrencyFormatter.format(widget.thresholdAmount), '88%', AppTheme.orange)),
                            VerticalDivider(color: Colors.grey[300], thickness: 1, width: 1),
                            Expanded(child: _buildInlineMetric('Over By', CurrencyFormatter.format(exceeded), '${percentOver.toStringAsFixed(0)}%', AppTheme.red)),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Progress visualization
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Spending Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: (percentUsed / 100).clamp(0, 1),
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(_getSeverityColor()),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Start',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Threshold',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Budget Max',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Budget adjustment suggestions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: AppTheme.primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Smart Reallocation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildReallocationSuggestion(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recommendations
                const Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSuggestion(
                  'Review your recent $category expenses',
                  Icons.search_rounded,
                ),
                _buildSuggestion(
                  'Consider adjusting your budget or spending habits',
                  Icons.edit_note_rounded,
                ),
                _buildSuggestion(
                  'Set up a savings rule to prevent overspending',
                  Icons.savings_rounded,
                ),
                _buildSuggestion(
                  'Track daily spending to stay within limits',
                  Icons.calendar_today_rounded,
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showSnoozeOptions(context);
                        },
                        icon: const Icon(Icons.snooze),
                        label: const Text('Snooze'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _dismissWithDuration(const Duration(days: 1), '1 day');
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Dismiss'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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

  Widget _buildReallocationSuggestion() {
    // Calculate suggested reallocation
    final overspent = exceeded;
    final categories = ['Entertainment', 'Shopping', 'Dining Out'];
    final reductionPerCategory = overspent / categories.length;

    return Column(
      children: [
        Text(
          'To balance your budget, consider reducing:',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        ...categories.map((cat) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.remove_circle_outline, size: 16, color: AppTheme.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$cat: ${CurrencyFormatter.format(reductionPerCategory)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildDetailCard(
      String label,
      String value,
      IconData icon,
      Color color,
      String subtitle,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildInlineMetric(String label, String value, String subtitle, Color color) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey[500],
        ),
      ),
    ],
  );
}

Widget _buildCompactMetric(String label, String value, String subtitle, Color color) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[500],
          ),
        ),
      ],
    ),
  );
}

// Container that fetches and displays alerts with debouncing
class EnhancedAlertBannersContainer extends StatefulWidget {
  final String userId;

  const EnhancedAlertBannersContainer({
    super.key,
    required this.userId,
  });

  @override
  State<EnhancedAlertBannersContainer> createState() => _EnhancedAlertBannersContainerState();
}

class _EnhancedAlertBannersContainerState extends State<EnhancedAlertBannersContainer> {
  List<Map<String, dynamic>>? _cachedAlerts;
  DateTime? _lastUpdate;

  // Debounce duration to prevent excessive rebuilds
  static const _debounceDuration = Duration(seconds: 2);

  bool _shouldUpdate(List<Map<String, dynamic>> newAlerts) {
    if (_lastUpdate == null) return true;
    if (_cachedAlerts == null) return true;
    if (_cachedAlerts!.length != newAlerts.length) return true;

    final timeSinceLastUpdate = DateTime.now().difference(_lastUpdate!);
    return timeSinceLastUpdate > _debounceDuration;
  }

  @override
  Widget build(BuildContext context) {
    final alertService = AlertService(widget.userId);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: alertService.getTriggeredAlertsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedAlerts == null) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          debugPrint('Error loading alerts: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        final triggeredAlerts = snapshot.data ?? _cachedAlerts ?? [];

        if (triggeredAlerts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Update cache if needed
        if (_shouldUpdate(triggeredAlerts)) {
          _cachedAlerts = triggeredAlerts;
          _lastUpdate = DateTime.now();
        }

        // Sort by exceeded amount (highest first)
        final sortedAlerts = List<Map<String, dynamic>>.from(triggeredAlerts)
          ..sort((a, b) {
            final exceededA = DataValidator.safeParseDouble(a['exceeded'], fallback: 0.0);
            final exceededB = DataValidator.safeParseDouble(b['exceeded'], fallback: 0.0);
            return exceededB.compareTo(exceededA);
          });

        return Column(
          key: ValueKey('alerts_${widget.userId}_${sortedAlerts.length}'),
          children: sortedAlerts.map((alertData) {
            final rule = alertData['rule'] as RuleModel?;
            if (rule == null) return const SizedBox.shrink();

            return EnhancedAlertBanner(
              key: ValueKey('${rule.id}_${alertData['currentSpending']}'),
              alertRule: rule,
              currentSpending: DataValidator.safeParseDouble(
                  alertData['currentSpending'],
                  fallback: 0.0
              ),
              budgetAmount: DataValidator.safeParseDouble(
                  alertData['budgetAmount'],
                  fallback: 0.0
              ),
              thresholdAmount: DataValidator.safeParseDouble(
                  alertData['thresholdAmount'],
                  fallback: 0.0
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// Global overlay wrapper for entire app
class GlobalAlertOverlay extends StatelessWidget {
  final String userId;
  final Widget child;

  const GlobalAlertOverlay({
    super.key,
    required this.userId,
    required this.child,
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
            bottom: false,
            child: EnhancedAlertBannersContainer(
              userId: userId,
            ),
          ),
        ),
      ],
    );
  }
}