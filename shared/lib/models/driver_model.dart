import 'package:cloud_firestore/cloud_firestore.dart';

class DriverModel {
  final String uid;
  final String name;
  final String phone;
  final String carModel;
  final String plateNumber;
  final double ratePerKm;
  final bool isOnline;
  final bool isApproved;
  final GeoPoint? location;
  final String geohash;
  final double rating;
  final int totalRides;
  final DateTime createdAt;

  const DriverModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.carModel,
    required this.plateNumber,
    required this.ratePerKm,
    this.isOnline = false,
    this.isApproved = false,
    this.location,
    this.geohash = '',
    this.rating = 0.0,
    this.totalRides = 0,
    required this.createdAt,
  });

  factory DriverModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return DriverModel(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      carModel: data['carModel'] as String? ?? '',
      plateNumber: data['plateNumber'] as String? ?? '',
      ratePerKm: (data['ratePerKm'] as num?)?.toDouble() ?? 0.0,
      isOnline: data['isOnline'] as bool? ?? false,
      isApproved: data['isApproved'] as bool? ?? false,
      location: data['location'] as GeoPoint?,
      geohash: data['geohash'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      totalRides: data['totalRides'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'carModel': carModel,
      'plateNumber': plateNumber,
      'ratePerKm': ratePerKm,
      'isOnline': isOnline,
      'isApproved': isApproved,
      'location': location,
      'geohash': geohash,
      'rating': rating,
      'totalRides': totalRides,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  DriverModel copyWith({
    String? uid,
    String? name,
    String? phone,
    String? carModel,
    String? plateNumber,
    double? ratePerKm,
    bool? isOnline,
    bool? isApproved,
    GeoPoint? location,
    String? geohash,
    double? rating,
    int? totalRides,
    DateTime? createdAt,
  }) {
    return DriverModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      carModel: carModel ?? this.carModel,
      plateNumber: plateNumber ?? this.plateNumber,
      ratePerKm: ratePerKm ?? this.ratePerKm,
      isOnline: isOnline ?? this.isOnline,
      isApproved: isApproved ?? this.isApproved,
      location: location ?? this.location,
      geohash: geohash ?? this.geohash,
      rating: rating ?? this.rating,
      totalRides: totalRides ?? this.totalRides,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
