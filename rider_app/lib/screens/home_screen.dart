import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-fetch GPS location as pickup on load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RideProvider>().setPickupFromGps();
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  Future<void> _findDrivers() async {
    final ride = context.read<RideProvider>();

    ride.pickupAddress = _pickupController.text.trim();
    ride.dropoffAddress = _dropoffController.text.trim();

    if (ride.pickupAddress.isEmpty || ride.dropoffAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter pickup and dropoff addresses')),
      );
      return;
    }

    // For now, use GPS position as pickup location (already set).
    // Dropoff coordinates would come from a geocoding service in production.
    // Using a placeholder offset for demo purposes.
    ride.dropoffLat ??= (ride.pickupLat ?? 0) + 0.02;
    ride.dropoffLng ??= (ride.pickupLng ?? 0) + 0.02;

    await ride.searchNearbyDrivers();

    if (!mounted) return;

    if (ride.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ride.error!)),
      );
    } else {
      Navigator.pushNamed(context, '/nearby-drivers');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ride = context.watch<RideProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Taxi App')),
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
                    child: Icon(Icons.person, size: 32, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.user?.name ?? 'Rider',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    auth.user?.phone ?? '',
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Where are you going?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pickupController,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Address',
                        prefixIcon: Icon(Icons.my_location, color: AppColors.primaryLight),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dropoffController,
                      decoration: const InputDecoration(
                        labelText: 'Dropoff Address',
                        prefixIcon: Icon(Icons.location_on, color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (ride.pickupLat != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'GPS: ${ride.pickupLat!.toStringAsFixed(4)}, ${ride.pickupLng!.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: ride.isSearching ? null : _findDrivers,
                      icon: ride.isSearching
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: const Text('Find Drivers'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
