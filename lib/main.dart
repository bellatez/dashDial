import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzl;
import 'package:timezone/timezone.dart' as tz;
import 'services/database_helper.dart';
import 'services/notification_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const DashdialApp());
}

class DashdialApp extends StatelessWidget {
  const DashdialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'dashDial',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/main': (context) => const AppLauncher(),
      },
    );
  }
}

class AppLauncher extends StatefulWidget {
  const AppLauncher({super.key});

  @override
  State<AppLauncher> createState() => _AppLauncherState();
}

class _AppLauncherState extends State<AppLauncher> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    tzl.initializeTimeZones();
    await DatabaseHelper.instance.database;
    await NotificationService().initialize();
    
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final onboardingComplete = await DatabaseHelper.instance.getSetting('onboarding_complete');
    
    if (onboardingComplete == 'true') {
      _navigateToHome();
    } else {
      _navigateToOnboarding();
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    }
  }

  void _navigateToOnboarding() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading screen while initializing
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
