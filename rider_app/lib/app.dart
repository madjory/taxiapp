import 'package:flutter/material.dart';

import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/home_screen.dart';
import 'screens/nearby_drivers_screen.dart';
import 'screens/ride_tracking_screen.dart';
import 'screens/ride_history_screen.dart';
import 'screens/profile_screen.dart';

class RiderApp extends StatelessWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxi App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/otp': (_) => const OtpScreen(),
        '/home': (_) => const HomeScreen(),
        '/nearby-drivers': (_) => const NearbyDriversScreen(),
        '/ride-tracking': (_) => const RideTrackingScreen(),
        '/ride-history': (_) => const RideHistoryScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}
