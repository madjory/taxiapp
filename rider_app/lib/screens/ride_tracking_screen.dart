import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/constants.dart';
import 'package:shared/utils/whatsapp_helper.dart';

import '../providers/ride_provider.dart';
import '../widgets/ride_status_banner.dart';

class RideTrackingScreen extends StatelessWidget {
  const RideTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();
    final currentRide = ride.currentRide;

    if (currentRide == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ride')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isActive = currentRide.status != RideStatus.completed &&
        currentRide.status != RideStatus.cancelled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Ride'),
        automaticallyImplyLeading: !isActive,
        leading: isActive ? const SizedBox.shrink() : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RideStatusBanner(status: currentRide.status),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: Icons.my_location,
                      label: 'Pickup',
                      value: currentRide.pickupAddress,
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Dropoff',
                      value: currentRide.dropoffAddress,
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.straighten,
                      label: 'Distance',
                      value:
                          '${currentRide.estimatedDistance.toStringAsFixed(1)} km',
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.attach_money,
                      label: 'Fare',
                      value:
                          '\$${currentRide.estimatedFare.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isActive) ...[
              ElevatedButton.icon(
                onPressed: () => _openWhatsApp(context),
                icon: const Icon(Icons.message),
                label: const Text('Contact Driver via WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                ),
              ),
              const SizedBox(height: 12),
              if (currentRide.status == RideStatus.requested)
                OutlinedButton.icon(
                  onPressed: () => _cancelRide(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel Ride'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
            ] else ...[
              ElevatedButton(
                onPressed: () {
                  ride.clearCurrentRide();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (_) => false,
                  );
                },
                child: const Text('Back to Home'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final ride = context.read<RideProvider>();
    final currentRide = ride.currentRide;
    if (currentRide == null) return;

    // Find driver phone from nearby drivers list.
    final driverData = ride.nearbyDrivers.firstWhere(
      (d) => d['uid'] == currentRide.driverId,
      orElse: () => {},
    );
    final phone = driverData['phone'] as String? ?? '';
    final driverName = driverData['name'] as String? ?? 'Driver';

    if (phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver phone number not available')),
        );
      }
      return;
    }

    await WhatsAppHelper.openWhatsApp(
      phone: phone,
      driverName: driverName,
      pickupAddress: currentRide.pickupAddress,
      dropoffAddress: currentRide.dropoffAddress,
      pickupLat: currentRide.pickupLocation.latitude,
      pickupLng: currentRide.pickupLocation.longitude,
      dropoffLat: currentRide.dropoffLocation.latitude,
      dropoffLng: currentRide.dropoffLocation.longitude,
    );
  }

  Future<void> _cancelRide(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<RideProvider>().cancelRide();
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
