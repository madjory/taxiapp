import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared/services/firestore_service.dart';
import 'package:shared/models/ride_model.dart';
import 'package:shared/constants.dart';

class RideProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  RideProvider(this._firestoreService);

  // --- Incoming ride requests ---
  List<RideModel> _incomingRequests = [];
  List<RideModel> get incomingRequests => _incomingRequests;

  // --- Active ride ---
  RideModel? _activeRide;
  RideModel? get activeRide => _activeRide;
  StreamSubscription<RideModel?>? _rideSubscription;

  // --- Ride history (all rides) ---
  List<RideModel> _allRides = [];
  List<RideModel> get allRides => _allRides;
  StreamSubscription<List<RideModel>>? _ridesSubscription;

  String? _error;
  String? get error => _error;

  /// Start listening to all rides for this driver.
  /// Splits them into incoming requests vs history internally.
  void listenToDriverRides(String driverId) {
    _ridesSubscription?.cancel();
    _ridesSubscription =
        _firestoreService.driverRidesStream(driverId).listen((rides) {
      _allRides = rides;

      // Find pending requests.
      _incomingRequests = rides
          .where((r) => r.status == RideStatus.requested)
          .toList();

      // Find active ride (accepted or in_progress).
      final active = rides.where((r) =>
          r.status == RideStatus.accepted ||
          r.status == RideStatus.inProgress);
      if (active.isNotEmpty && _activeRide?.id != active.first.id) {
        // New active ride detected — start streaming it.
        listenToRide(active.first.id);
      } else if (active.isEmpty) {
        _activeRide = null;
        _rideSubscription?.cancel();
      }

      notifyListeners();
    });
  }

  /// Stream a specific ride for real-time updates.
  void listenToRide(String rideId) {
    _rideSubscription?.cancel();
    _rideSubscription = _firestoreService.rideStream(rideId).listen((ride) {
      _activeRide = ride;
      notifyListeners();
    });
  }

  /// Accept a ride request.
  Future<bool> acceptRide(String rideId) async {
    _error = null;
    try {
      await _firestoreService.updateRideStatus(
        rideId: rideId,
        status: RideStatus.accepted,
      );
      listenToRide(rideId);
      return true;
    } catch (e) {
      _error = 'Failed to accept ride: $e';
      notifyListeners();
      return false;
    }
  }

  /// Start the ride (driver picked up rider).
  Future<void> startRide() async {
    if (_activeRide == null) return;
    _error = null;
    try {
      await _firestoreService.updateRideStatus(
        rideId: _activeRide!.id,
        status: RideStatus.inProgress,
      );
    } catch (e) {
      _error = 'Failed to start ride: $e';
      notifyListeners();
    }
  }

  /// Complete the ride.
  Future<void> completeRide() async {
    if (_activeRide == null) return;
    _error = null;
    try {
      await _firestoreService.updateRideStatus(
        rideId: _activeRide!.id,
        status: RideStatus.completed,
      );
    } catch (e) {
      _error = 'Failed to complete ride: $e';
      notifyListeners();
    }
  }

  /// Cancel the ride.
  Future<void> cancelRide() async {
    if (_activeRide == null) return;
    _error = null;
    try {
      await _firestoreService.updateRideStatus(
        rideId: _activeRide!.id,
        status: RideStatus.cancelled,
      );
    } catch (e) {
      _error = 'Failed to cancel ride: $e';
      notifyListeners();
    }
  }

  /// Clear active ride reference.
  void clearActiveRide() {
    _rideSubscription?.cancel();
    _activeRide = null;
    notifyListeners();
  }

  /// Completed rides only (for history screen).
  List<RideModel> get completedRides => _allRides
      .where((r) =>
          r.status == RideStatus.completed ||
          r.status == RideStatus.cancelled)
      .toList();

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _ridesSubscription?.cancel();
    super.dispose();
  }
}
