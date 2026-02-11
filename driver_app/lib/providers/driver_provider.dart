import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/services/firestore_service.dart';
import 'package:shared/services/location_service.dart';

class DriverProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final LocationService _locationService;

  DriverProvider(this._firestoreService, this._locationService);

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  StreamSubscription? _locationSubscription;

  String? _error;
  String? get error => _error;

  /// Toggle online/offline status and start/stop location streaming.
  Future<void> toggleOnline(String driverUid) async {
    _error = null;

    try {
      if (_isOnline) {
        // Go offline.
        await _firestoreService.setDriverOnlineStatus(driverUid, false);
        _locationSubscription?.cancel();
        _locationSubscription = null;
        _isOnline = false;
      } else {
        // Go online — get initial position, then stream updates.
        final pos = await _locationService.getCurrentPosition();
        await _firestoreService.updateDriverLocation(
          driverUid,
          GeoPoint(pos.latitude, pos.longitude),
        );
        await _firestoreService.setDriverOnlineStatus(driverUid, true);
        _isOnline = true;

        _locationSubscription = _locationService
            .getPositionStream(distanceFilter: 20)
            .listen((pos) {
          _firestoreService.updateDriverLocation(
            driverUid,
            GeoPoint(pos.latitude, pos.longitude),
          );
        });
      }
    } catch (e) {
      _error = 'Location error: $e';
    }

    notifyListeners();
  }

  /// Force go offline (e.g. on sign out).
  Future<void> goOffline(String driverUid) async {
    if (!_isOnline) return;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isOnline = false;

    try {
      await _firestoreService.setDriverOnlineStatus(driverUid, false);
    } catch (_) {}

    notifyListeners();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}
