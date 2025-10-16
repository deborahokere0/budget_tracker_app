import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/rule_model.dart';
import '../utils/currency_formatter.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Initialize notification service
  static Future<void> initialize() async {
    // Request permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Notification permissions granted');
    }

    // Initialize local notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settingsInit = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(
      settingsInit,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_foregroundMessageHandler);
  }

  // Get FCM token for push notifications
  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  // Send alert notification
  static Future<void> sendAlertNotification({
    required RuleModel rule,
    required double currentSpending,
  }) async {
    final threshold = rule.conditions['threshold'] ?? 0.0;
    final category = rule.conditions['category'] ?? 'Unknown';
    final exceeded = currentSpending - threshold;

    await _notifications.show(
      rule.id.hashCode,
      '⚠️ Budget Alert: ${rule.name}',
      '$category spending ${CurrencyFormatter.format(currentSpending)} exceeded threshold ${CurrencyFormatter.format(threshold)} by ${CurrencyFormatter.format(exceeded)}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alerts',
          'Budget Alerts',
          channelDescription: 'Notifications for budget threshold alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFFF9800), // Orange
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'alert_${rule.id}',
    );
  }

  // Send savings goal notification
  static Future<void> sendSavingsGoalNotification({
    required RuleModel rule,
    required double progress,
  }) async {
    String title = '';
    String body = '';

    if (progress >= 100) {
      title = '🎉 Goal Achieved!';
      body = 'Congratulations! You\'ve reached your ${rule.goalName} goal of ${CurrencyFormatter.format(rule.targetAmount ?? 0)}';
    } else if (progress >= 75) {
      title = '🎯 Almost There!';
      body = 'You\'re ${progress.toStringAsFixed(0)}% towards your ${rule.goalName} goal!';
    } else if (progress >= 50) {
      title = '💪 Halfway There!';
      body = 'You\'re ${progress.toStringAsFixed(0)}% towards your ${rule.goalName} goal!';
    } else if (progress >= 25) {
      title = '🌱 Great Progress!';
      body = 'You\'re ${progress.toStringAsFixed(0)}% towards your ${rule.goalName} goal!';
    }

    if (title.isNotEmpty) {
      await _notifications.show(
        rule.id.hashCode + 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'savings_goals',
            'Savings Goals',
            channelDescription: 'Notifications for savings goal progress',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF4CAF50), // Green
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'savings_${rule.id}',
      );
    }
  }

  // Send allocation notification
  static Future<void> sendAllocationNotification({
    required String ruleName,
    required double amount,
    required double percentage,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '💰 Auto-Allocation Applied',
      '$ruleName: ${CurrencyFormatter.format(amount)} (${percentage.toStringAsFixed(0)}%) saved automatically',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'allocations',
          'Auto-Allocations',
          channelDescription: 'Notifications for automatic savings allocations',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF2196F3), // Blue
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: false,
        ),
      ),
    );
  }

  // Send reminder notification
  static Future<void> sendReminderNotification({
    required String title,
    required String body,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Reminders',
          channelDescription: 'General reminder notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all notifications
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      // Navigate based on payload
      // This would be handled by your navigation service
      print('Notification tapped: $payload');
    }
  }

  // Handle background messages
  static Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    print('Background message: ${message.notification?.title}');
  }

  // Handle foreground messages
  static void _foregroundMessageHandler(RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');

    // Show local notification
    if (message.notification != null) {
      _notifications.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default',
            'Default',
            channelDescription: 'Default notification channel',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }
}