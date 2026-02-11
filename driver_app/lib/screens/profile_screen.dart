import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<AuthProvider>().driver;
    final dateFormat = DateFormat('MMM d, y');

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 48,
              child: Icon(Icons.drive_eta, size: 48),
            ),
            const SizedBox(height: 8),
            Text(
              driver?.name ?? 'Driver',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (driver?.isApproved ?? false)
                    ? AppColors.online.withValues(alpha: 0.15)
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                (driver?.isApproved ?? false) ? 'Approved' : 'Pending Approval',
                style: TextStyle(
                  color: (driver?.isApproved ?? false)
                      ? AppColors.online
                      : Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stats row.
            Row(
              children: [
                _StatCard(
                  icon: Icons.star,
                  iconColor: Colors.amber,
                  label: 'Rating',
                  value: (driver?.rating ?? 0) > 0
                      ? driver!.rating.toStringAsFixed(1)
                      : 'New',
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.directions_car,
                  iconColor: AppColors.primary,
                  label: 'Total Rides',
                  value: '${driver?.totalRides ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info card.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('Phone'),
                      subtitle: Text(driver?.phone ?? '-'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.directions_car),
                      title: const Text('Car Model'),
                      subtitle: Text(driver?.carModel ?? '-'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.confirmation_number),
                      title: const Text('Plate Number'),
                      subtitle: Text(driver?.plateNumber ?? '-'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.attach_money),
                      title: const Text('Rate per km'),
                      subtitle: Text(
                        '\$${driver?.ratePerKm.toStringAsFixed(2) ?? '0.00'}',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Member Since'),
                      subtitle: Text(
                        driver != null
                            ? dateFormat.format(driver.createdAt)
                            : '-',
                      ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
