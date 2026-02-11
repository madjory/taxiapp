import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared/services/auth_service.dart';
import 'package:shared/services/firestore_service.dart';
import 'package:shared/services/location_service.dart';

import 'providers/auth_provider.dart';
import 'providers/ride_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final authService = AuthService();
  final firestoreService = FirestoreService();
  final locationService = LocationService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService, firestoreService),
        ),
        ChangeNotifierProvider(
          create: (_) => RideProvider(firestoreService, locationService),
        ),
      ],
      child: const RiderApp(),
    ),
  );
}
