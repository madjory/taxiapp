import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/ride_provider.dart';
import '../widgets/ride_request_card.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().firebaseUser?.uid;
      if (uid != null) {
        context.read<RideProvider>().listenToDriverRides(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final driverProv = context.watch<DriverProvider>();
    final rideProv = context.watch<RideProvider>();
    final driver = auth.driver;
    final isApproved = driver?.isApproved ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Home'),
        actions: [
          // Online/offline toggle in the app bar.
          if (isApproved)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Text(
                    driverProv.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: driverProv.isOnline
                          ? AppColors.accent
                          : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: driverProv.isOnline,
                    onChanged: (_) {
                      final uid = auth.firebaseUser?.uid;
                      if (uid != null) {
                        driverProv.toggleOnline(uid);
                      }
                    },
                    activeColor: AppColors.accent,
                  ),
                ],
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child:
                        Icon(Icons.drive_eta, size: 32, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    driver?.name ?? 'Driver',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    driver?.carModel ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Ride History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/ride-history');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () async {
                Navigator.pop(context);
                final uid = auth.firebaseUser?.uid;
                if (uid != null) {
                  await driverProv.goOffline(uid);
                }
                await auth.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (_) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: _buildBody(context, isApproved, driverProv, rideProv),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isApproved,
    DriverProvider driverProv,
    RideProvider rideProv,
  ) {
    // Not approved yet.
    if (!isApproved) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Pending Approval',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your account is under review. You will be able to go online once an admin approves your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Offline.
    if (!driverProv.isOnline) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'You are offline',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Toggle the switch above to go online and start receiving ride requests.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Active ride exists — show a banner to navigate to it.
    if (rideProv.activeRide != null) {
      return Column(
        children: [
          Material(
            color: AppColors.primaryLight,
            child: ListTile(
              leading: const Icon(Icons.directions_car, color: Colors.white),
              title: const Text(
                'You have an active ride',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              trailing:
                  const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onTap: () => Navigator.pushNamed(context, '/active-ride'),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('Tap above to manage your current ride.'),
            ),
          ),
        ],
      );
    }

    // Online with incoming requests.
    if (rideProv.incomingRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Waiting for ride requests...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rideProv.incomingRequests.length,
      itemBuilder: (context, index) {
        final ride = rideProv.incomingRequests[index];
        return RideRequestCard(
          ride: ride,
          onAccept: () async {
            final success = await rideProv.acceptRide(ride.id);
            if (success && context.mounted) {
              Navigator.pushNamed(context, '/active-ride');
            }
          },
        );
      },
    );
  }
}
