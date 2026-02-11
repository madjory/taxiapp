import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ride_provider.dart';
import '../widgets/driver_card.dart';

class NearbyDriversScreen extends StatelessWidget {
  const NearbyDriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final drivers = ride.nearbyDrivers;

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Drivers')),
      body: drivers.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.no_transfer, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No drivers found nearby',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try again in a few moments',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                final driver = drivers[index];
                return DriverCard(
                  driver: driver,
                  onBook: () => _bookRide(context, driver['uid'] as String),
                );
              },
            ),
    );
  }

  Future<void> _bookRide(BuildContext context, String driverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Booking'),
        content: const Text('Book a ride with this driver?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Book'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ride = context.read<RideProvider>();
    final rideId = await ride.bookRide(driverId: driverId);

    if (!context.mounted) return;

    if (rideId != null) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/ride-tracking',
        (route) => route.settings.name == '/home',
      );
    } else if (ride.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ride.error!)),
      );
    }
  }
}
