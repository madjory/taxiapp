import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared/services/firestore_service.dart';
import 'package:shared/services/location_service.dart';
import 'package:shared/models/ride_model.dart';
import 'package:shared/constants.dart';

class RideProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final LocationService _locationService;

  RideProvider(this._firestoreService, this._locationService);

  // --- Nearby drivers ---
  List<Map<String, dynamic>> _nearbyDrivers = [];
  List<Map<String, dynamic>> get nearbyDrivers => _nearbyDrivers;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  // --- Current ride ---
  RideModel? _currentRide;
  RideModel? get currentRide => _currentRide;
  StreamSubscription<RideModel?>? _rideSubscription;

  // --- Ride history ---
  List<RideModel> _rideHistory = [];
  List<RideModel> get rideHistory => _rideHistory;
  StreamSubscription<List<RideModel>>? _historySubscription;

  // --- Ride input ---
  String pickupAddress = '';
  String dropoffAddress = '';
  double? pickupLat;
  double? pickupLng;
  double? dropoffLat;
  double? dropoffLng;

  String? _error;
  String? get error => _error;

  /// Fetch the rider's current GPS position and set as pickup.
  Future<void> setPickupFromGps() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      pickupLat = pos.latitude;
      pickupLng = pos.longitude;
      notifyListeners();
    } catch (e) {
      _error = 'Could not get location: $e';
      notifyListeners();
    }
  }

  /// Search for nearby drivers from the rider's pickup location.
  Future<void> searchNearbyDrivers() async {
    if (pickupLat == null || pickupLng == null) {
      _error = 'Pickup location not set';
      notifyListeners();
      return;
    }

    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      _nearbyDrivers = await _firestoreService.getNearbyDrivers(
        latitude: pickupLat!,
        longitude: pickupLng!,
      );
    } catch (e) {
      _error = 'Failed to find drivers: $e';
    }

    _isSearching = false;
    notifyListeners();
  }

  /// Book a ride with the selected driver.
  Future<String?> bookRide({required String driverId}) async {
    if (pickupLat == null ||
        pickupLng == null ||
        dropoffLat == null ||
        dropoffLng == null) {
      _error = 'Pickup and dropoff locations are required';
      notifyListeners();
      return null;
    }

    _error = null;
    notifyListeners();

    try {
      final distance = _locationService.distanceBetween(
        pickupLat!,
        pickupLng!,
        dropoffLat!,
        dropoffLng!,
      );

      // Find driver's rate from the nearby drivers list.
      final driverData = _nearbyDrivers.firstWhere(
        (d) => d['uid'] == driverId,
        orElse: () => {},
      );
      final ratePerKm = (driverData['ratePerKm'] as num?)?.toDouble() ?? 5.0;
      final fare = distance * ratePerKm;

      final rideId = await _firestoreService.createRideRequest(
        driverId: driverId,
        pickupLatitude: pickupLat!,
        pickupLongitude: pickupLng!,
        pickupAddress: pickupAddress,
        dropoffLatitude: dropoffLat!,
        dropoffLongitude: dropoffLng!,
        dropoffAddress: dropoffAddress,
        estimatedDistance: distance,
        estimatedFare: fare,
      );

      listenToRide(rideId);
      return rideId;
    } catch (e) {
      _error = 'Failed to book ride: $e';
      notifyListeners();
      return null;
    }
  }

  /// Start listening to a specific ride's real-time updates.
  void listenToRide(String rideId) {
    _rideSubscription?.cancel();
    _rideSubscription = _firestoreService.rideStream(rideId).listen((ride) {
      _currentRide = ride;
      notifyListeners();
    });
  }

  /// Cancel the current ride.
  Future<void> cancelRide() async {
    if (_currentRide == null) return;
    try {
      await _firestoreService.updateRideStatus(
        rideId: _currentRide!.id,
        status: RideStatus.cancelled,
      );
    } catch (e) {
      _error = 'Failed to cancel ride: $e';
      notifyListeners();
    }
  }

  /// Start listening to the rider's ride history.
  void listenToRideHistory(String riderId) {
    _historySubscription?.cancel();
    _historySubscription =
        _firestoreService.riderRidesStream(riderId).listen((rides) {
      _rideHistory = rides;
      notifyListeners();
    });
  }

  /// Clear the current ride when done.
  void clearCurrentRide() {
    _rideSubscription?.cancel();
    _currentRide = null;
    notifyListeners();
  }

  /// Reset search state.
  void clearSearch() {
    _nearbyDrivers = [];
    pickupAddress = '';
    dropoffAddress = '';
    pickupLat = null;
    pickupLng = null;
    dropoffLat = null;
    dropoffLng = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _historySubscription?.cancel();
    super.dispose();
  }
}
