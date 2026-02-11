import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/constants.dart';
import 'package:shared/utils/whatsapp_helper.dart';

import '../providers/ride_provider.dart';
import '../widgets/ride_status_banner.dart';

class ActiveRideScreen extends StatelessWidget {
  const ActiveRideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rideProv = context.watch<RideProvider>();
    final ride = rideProv.activeRide;

    if (ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ride')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isTerminal = ride.status == RideStatus.completed ||
        ride.status == RideStatus.cancelled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Ride'),
        automaticallyImplyLeading: isTerminal,
        leading: isTerminal ? null : const SizedBox.shrink(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RideStatusBanner(status: ride.status),
            const SizedBox(height: 16),

            // Ride details card.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: Icons.my_location,
                      iconColor: Colors.green,
                      label: 'Pickup',
                      value: ride.pickupAddress,
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.location_on,
                      iconColor: Colors.red,
                      label: 'Dropoff',
                      value: ride.dropoffAddress,
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoRow(
                            icon: Icons.straighten,
                            iconColor: Colors.grey,
                            label: 'Distance',
                            value:
                                '${ride.estimatedDistance.toStringAsFixed(1)} km',
                          ),
                        ),
                        Expanded(
                          child: _InfoRow(
                            icon: Icons.attach_money,
                            iconColor: Colors.grey,
                            label: 'Fare',
                            value:
                                '\$${ride.estimatedFare.toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons based on ride status.
            if (ride.status == RideStatus.accepted) ...[
              ElevatedButton.icon(
                onPressed: () => _startRide(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Ride (Rider Picked Up)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 12),
              _whatsAppButton(context),
              const SizedBox(height: 12),
              _cancelButton(context),
            ] else if (ride.status == RideStatus.inProgress) ...[
              ElevatedButton.icon(
                onPressed: () => _completeRide(context),
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete Ride'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 12),
              _whatsAppButton(context),
            ] else if (isTerminal) ...[
              ElevatedButton(
                onPressed: () {
                  rideProv.clearActiveRide();
                  Navigator.pop(context);
                },
                child: const Text('Back to Home'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _whatsAppButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _openWhatsApp(context),
      icon: const Icon(Icons.message),
      label: const Text('Message Rider via WhatsApp'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF25D366),
      ),
    );
  }

  Widget _cancelButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _cancelRide(context),
      icon: const Icon(Icons.close),
      label: const Text('Cancel Ride'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red),
      ),
    );
  }

  Future<void> _startRide(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Ride'),
        content: const Text('Confirm that you have picked up the rider?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<RideProvider>().startRide();
    }
  }

  Future<void> _completeRide(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Ride'),
        content: const Text('Confirm that the rider has been dropped off?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<RideProvider>().completeRide();
    }
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

  Future<void> _openWhatsApp(BuildContext context) async {
    final ride = context.read<RideProvider>().activeRide;
    if (ride == null) return;

    // The rider's phone isn't directly available in the ride model
    // (phone is protected by security rules). In production, you'd
    // fetch it via a Cloud Function. For now, show a placeholder message.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Rider contact will be available via Cloud Function in production'),
        ),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
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
