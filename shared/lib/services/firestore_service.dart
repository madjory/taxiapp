import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../constants.dart';
import '../models/user_model.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // -------------------------------------------------------------------------
  // Users
  // -------------------------------------------------------------------------

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection(Collections.users).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _firestore.collection(Collections.users).doc(uid).update(data);
  }

  // -------------------------------------------------------------------------
  // Drivers
  // -------------------------------------------------------------------------

  Future<DriverModel?> getDriver(String uid) async {
    final doc = await _firestore.collection(Collections.drivers).doc(uid).get();
    if (!doc.exists) return null;
    return DriverModel.fromFirestore(doc);
  }

  Future<void> createDriver(DriverModel driver) {
    return _firestore
        .collection(Collections.drivers)
        .doc(driver.uid)
        .set(driver.toFirestore());
  }

  Future<void> updateDriverLocation(String uid, GeoPoint location) {
    return _firestore.collection(Collections.drivers).doc(uid).update({
      'location': location,
    });
  }

  Future<void> setDriverOnlineStatus(String uid, bool isOnline) {
    return _firestore.collection(Collections.drivers).doc(uid).update({
      'isOnline': isOnline,
    });
  }

  /// Calls the getNearbyDrivers Cloud Function.
  Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = defaultSearchRadiusKm,
  }) async {
    final result = await _functions.httpsCallable('getNearbyDrivers').call({
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
    });
    final data = result.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['drivers'] as List);
  }

  // -------------------------------------------------------------------------
  // Rides
  // -------------------------------------------------------------------------

  /// Calls the createRideRequest Cloud Function.
  Future<String> createRideRequest({
    required String driverId,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String dropoffAddress,
    required double estimatedDistance,
    required double estimatedFare,
  }) async {
    final result = await _functions.httpsCallable('createRideRequest').call({
      'driverId': driverId,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'pickupAddress': pickupAddress,
      'dropoffLatitude': dropoffLatitude,
      'dropoffLongitude': dropoffLongitude,
      'dropoffAddress': dropoffAddress,
      'estimatedDistance': estimatedDistance,
      'estimatedFare': estimatedFare,
    });
    return (result.data as Map<String, dynamic>)['rideId'] as String;
  }

  /// Calls the updateRideStatus Cloud Function.
  Future<void> updateRideStatus({
    required String rideId,
    required String status,
  }) async {
    await _functions.httpsCallable('updateRideStatus').call({
      'rideId': rideId,
      'status': status,
    });
  }

  /// Stream rides for a rider.
  Stream<List<RideModel>> riderRidesStream(String riderId) {
    return _firestore
        .collection(Collections.rides)
        .where('riderId', isEqualTo: riderId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(RideModel.fromFirestore).toList());
  }

  /// Stream rides for a driver.
  Stream<List<RideModel>> driverRidesStream(String driverId) {
    return _firestore
        .collection(Collections.rides)
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(RideModel.fromFirestore).toList());
  }

  /// Stream a single ride document.
  Stream<RideModel?> rideStream(String rideId) {
    return _firestore
        .collection(Collections.rides)
        .doc(rideId)
        .snapshots()
        .map((doc) => doc.exists ? RideModel.fromFirestore(doc) : null);
  }
}
