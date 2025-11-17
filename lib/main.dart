import 'dart:async';
import 'package:budget_tracker_app/screens/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/rules/rules_screen.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/alert_service.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Notification Service
  await NotificationService.initialize();

  runApp(const BudgetTrackerApp());
}

class BudgetTrackerApp extends StatefulWidget {
  const BudgetTrackerApp({super.key});

  @override
  State<BudgetTrackerApp> createState() => _BudgetTrackerAppState();
}

class _BudgetTrackerAppState extends State<BudgetTrackerApp>
    with WidgetsBindingObserver {
  final FirebaseService _firebaseService = FirebaseService();
  Timer? _alertCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupPeriodicAlertCheck();
  }

  @override
  void dispose() {
    _alertCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Check alerts when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _checkAlertsOnResume();
    }
  }

  // Setup periodic alert checking (every 30 minutes when app is active)
  void _setupPeriodicAlertCheck() {
    _alertCheckTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (mounted) {
        _checkAlertsOnResume();
      }
    });
  }

  Future<void> _checkAlertsOnResume() async {
    final userId = _firebaseService.currentUserId;
    if (userId != null) {
      final alertService = AlertService(userId);
      await alertService.checkAndTriggerAlerts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Dee's Budget App",
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routes: {
        '/': (context) => _buildAuthGate(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
        '/rules': (context) => const RulesScreen(),
      },
      initialRoute: '/',
    );
  }

  Widget _buildAuthGate() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}