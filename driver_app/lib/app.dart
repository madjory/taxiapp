import 'package:flutter/material.dart';

import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/home_screen.dart';
import 'screens/active_ride_screen.dart';
import 'screens/ride_history_screen.dart';
import 'screens/profile_screen.dart';

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxi App - Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/otp': (_) => const OtpScreen(),
        '/register': (_) => const RegistrationScreen(),
        '/home': (_) => const HomeScreen(),
        '/active-ride': (_) => const ActiveRideScreen(),
        '/ride-history': (_) => const RideHistoryScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}
