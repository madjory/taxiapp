import 'package:flutter/material.dart';

import '../theme.dart';

class DriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onBook;

  const DriverCard({
    super.key,
    required this.driver,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final name = driver['name'] as String? ?? 'Unknown';
    final carModel = driver['carModel'] as String? ?? '';
    final plateNumber = driver['plateNumber'] as String? ?? '';
    final ratePerKm = (driver['ratePerKm'] as num?)?.toDouble() ?? 0.0;
    final rating = (driver['rating'] as num?)?.toDouble() ?? 0.0;
    final totalRides = (driver['totalRides'] as num?)?.toInt() ?? 0;
    final distanceKm = (driver['distanceKm'] as num?)?.toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$carModel  ·  $plateNumber',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (distanceKm != null)
                  Chip(
                    label: Text('${distanceKm.toStringAsFixed(1)} km'),
                    backgroundColor: AppColors.background,
                    labelStyle: const TextStyle(fontSize: 12),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  rating > 0 ? rating.toStringAsFixed(1) : 'New',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 12),
                const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '$totalRides rides',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  '\$${ratePerKm.toStringAsFixed(2)}/km',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBook,
                child: const Text('Book This Driver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
