import 'package:flutter/material.dart';
import 'package:shared/constants.dart';

class RideStatusBanner extends StatelessWidget {
  final String status;

  const RideStatusBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon, String text) = switch (status) {
      RideStatus.requested => (
          Colors.orange.shade100,
          Colors.orange.shade800,
          Icons.hourglass_top,
          'Waiting for driver to accept',
        ),
      RideStatus.accepted => (
          Colors.blue.shade100,
          Colors.blue.shade800,
          Icons.check_circle,
          'Driver accepted — on the way to pickup',
        ),
      RideStatus.inProgress => (
          Colors.purple.shade100,
          Colors.purple.shade800,
          Icons.directions_car,
          'Ride in progress',
        ),
      RideStatus.completed => (
          Colors.green.shade100,
          Colors.green.shade800,
          Icons.done_all,
          'Ride completed',
        ),
      RideStatus.cancelled => (
          Colors.red.shade100,
          Colors.red.shade800,
          Icons.cancel,
          'Ride cancelled',
        ),
      _ => (
          Colors.grey.shade100,
          Colors.grey.shade800,
          Icons.info,
          status,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
