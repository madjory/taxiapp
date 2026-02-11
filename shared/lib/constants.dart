/// Firestore collection names.
class Collections {
  Collections._();

  static const String users = 'users';
  static const String drivers = 'drivers';
  static const String rides = 'rides';
}

/// Ride status values.
class RideStatus {
  RideStatus._();

  static const String requested = 'requested';
  static const String accepted = 'accepted';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const List<String> all = [
    requested,
    accepted,
    inProgress,
    completed,
    cancelled,
  ];
}

/// Geohash precision for proximity queries.
const int geohashPrecision = 6;

/// Default search radius in km.
const double defaultSearchRadiusKm = 10.0;
