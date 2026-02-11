import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  WhatsAppHelper._();

  /// Build a WhatsApp deep link URL with pre-filled message.
  static Uri buildWhatsAppUrl({
    required String phone,
    required String driverName,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) {
    final pickupMapLink =
        'https://www.google.com/maps/search/?api=1&query=$pickupLat,$pickupLng';
    final dropoffMapLink =
        'https://www.google.com/maps/search/?api=1&query=$dropoffLat,$dropoffLng';

    final message = 'Hi $driverName, I booked a ride.\n\n'
        'Pickup: $pickupAddress\n$pickupMapLink\n\n'
        'Dropoff: $dropoffAddress\n$dropoffMapLink';

    // Remove leading + if present, WhatsApp expects just digits
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    return Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
  }

  /// Open WhatsApp with the pre-filled ride message.
  static Future<bool> openWhatsApp({
    required String phone,
    required String driverName,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final uri = buildWhatsAppUrl(
      phone: phone,
      driverName: driverName,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}
