import 'package:equatable/equatable.dart';

class CustomerTruckModel extends Equatable {
  const CustomerTruckModel({
    required this.id,
    required this.driverId,
    required this.location,
    required this.availableFrom,
    required this.driverName,
    required this.vehicleType,
    required this.bodyType,
    required this.registrationLabel,
    required this.lengthFt,
    required this.capacityTonnes,
    this.preferredDestination,
    this.distanceKm,
    this.note = '',
  });

  final String id, driverId, location, driverName;
  final String vehicleType, bodyType, note, registrationLabel;
  final double lengthFt, capacityTonnes;
  final double? distanceKm;
  final DateTime availableFrom;
  final String? preferredDestination;

  factory CustomerTruckModel.fromJson(Map<String, dynamic> json) {
    final vehicle = Map<String, dynamic>.from(json['vehicle'] as Map);
    return CustomerTruckModel(
      id: json['id'].toString(),
      driverId: json['driver_id'].toString(),
      location: json['current_location']?.toString() ?? '',
      availableFrom: DateTime.parse(json['available_from'].toString()),
      driverName: json['driver_name']?.toString() ?? 'Driver',
      vehicleType: vehicle['vehicle_type']?.toString() ?? 'Truck',
      bodyType: vehicle['body_type']?.toString() ?? 'Truck',
      registrationLabel: vehicle['registration_label']?.toString() ?? 'Truck',
      lengthFt: (vehicle['length_ft'] as num?)?.toDouble() ?? 0,
      capacityTonnes: (vehicle['capacity_tonnes'] as num?)?.toDouble() ?? 0,
      preferredDestination: json['preferred_destination']?.toString(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      note: json['note']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [
    id,
    driverId,
    location,
    availableFrom,
    driverName,
    vehicleType,
    bodyType,
    registrationLabel,
    lengthFt,
    capacityTonnes,
    preferredDestination,
    distanceKm,
    note,
  ];
}
