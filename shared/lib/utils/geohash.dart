import 'dart:math';

/// Dart implementation of geohash encoding for proximity queries.
/// Compatible with geofire-common used in Cloud Functions.
class Geohash {
  Geohash._();

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encode a lat/lng pair into a geohash string.
  static String encode(double latitude, double longitude, {int precision = 6}) {
    double latMin = -90.0, latMax = 90.0;
    double lngMin = -180.0, lngMax = 180.0;

    final buffer = StringBuffer();
    var isLng = true;
    var bits = 0;
    var charIndex = 0;

    while (buffer.length < precision) {
      if (isLng) {
        final mid = (lngMin + lngMax) / 2;
        if (longitude >= mid) {
          charIndex = charIndex * 2 + 1;
          lngMin = mid;
        } else {
          charIndex = charIndex * 2;
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          charIndex = charIndex * 2 + 1;
          latMin = mid;
        } else {
          charIndex = charIndex * 2;
          latMax = mid;
        }
      }

      isLng = !isLng;
      bits++;

      if (bits == 5) {
        buffer.write(_base32[charIndex]);
        bits = 0;
        charIndex = 0;
      }
    }

    return buffer.toString();
  }

  /// Decode a geohash string back to approximate lat/lng.
  static ({double latitude, double longitude}) decode(String geohash) {
    double latMin = -90.0, latMax = 90.0;
    double lngMin = -180.0, lngMax = 180.0;
    var isLng = true;

    for (var i = 0; i < geohash.length; i++) {
      final charIndex = _base32.indexOf(geohash[i]);
      for (var bit = 4; bit >= 0; bit--) {
        final bitValue = (charIndex >> bit) & 1;
        if (isLng) {
          final mid = (lngMin + lngMax) / 2;
          if (bitValue == 1) {
            lngMin = mid;
          } else {
            lngMax = mid;
          }
        } else {
          final mid = (latMin + latMax) / 2;
          if (bitValue == 1) {
            latMin = mid;
          } else {
            latMax = mid;
          }
        }
        isLng = !isLng;
      }
    }

    return (
      latitude: (latMin + latMax) / 2,
      longitude: (lngMin + lngMax) / 2,
    );
  }

  /// Calculate the approximate error margin for a given precision.
  static ({double latError, double lngError}) errorMargin(int precision) {
    final latBits = (precision * 5) ~/ 2;
    final lngBits = precision * 5 - latBits;
    return (
      latError: 180.0 / pow(2, latBits),
      lngError: 360.0 / pow(2, lngBits),
    );
  }
}
