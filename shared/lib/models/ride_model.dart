import 'package:cloud_firestore/cloud_firestore.dart';

class RideModel {
  final String id;
  final String riderId;
  final String driverId;
  final GeoPoint pickupLocation;
  final String pickupAddress;
  final GeoPoint dropoffLocation;
  final String dropoffAddress;
  final double estimatedDistance;
  final double estimatedFare;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double? riderRating;
  final double? driverRating;

  const RideModel({
    required this.id,
    required this.riderId,
    required this.driverId,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.dropoffLocation,
    required this.dropoffAddress,
    required this.estimatedDistance,
    required this.estimatedFare,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.riderRating,
    this.driverRating,
  });

  factory RideModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return RideModel(
      id: doc.id,
      riderId: data['riderId'] as String? ?? '',
      driverId: data['driverId'] as String? ?? '',
      pickupLocation: data['pickupLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      pickupAddress: data['pickupAddress'] as String? ?? '',
      dropoffLocation: data['dropoffLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      dropoffAddress: data['dropoffAddress'] as String? ?? '',
      estimatedDistance: (data['estimatedDistance'] as num?)?.toDouble() ?? 0.0,
      estimatedFare: (data['estimatedFare'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'requested',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      riderRating: (data['riderRating'] as num?)?.toDouble(),
      driverRating: (data['driverRating'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'riderId': riderId,
      'driverId': driverId,
      'pickupLocation': pickupLocation,
      'pickupAddress': pickupAddress,
      'dropoffLocation': dropoffLocation,
      'dropoffAddress': dropoffAddress,
      'estimatedDistance': estimatedDistance,
      'estimatedFare': estimatedFare,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'riderRating': riderRating,
      'driverRating': driverRating,
    };
  }

  RideModel copyWith({
    String? id,
    String? riderId,
    String? driverId,
    GeoPoint? pickupLocation,
    String? pickupAddress,
    GeoPoint? dropoffLocation,
    String? dropoffAddress,
    double? estimatedDistance,
    double? estimatedFare,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
    double? riderRating,
    double? driverRating,
  }) {
    return RideModel(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      driverId: driverId ?? this.driverId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      riderRating: riderRating ?? this.riderRating,
      driverRating: driverRating ?? this.driverRating,
    );
  }
}
