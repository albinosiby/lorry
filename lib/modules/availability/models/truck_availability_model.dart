import 'package:equatable/equatable.dart';
import '../../vehicles/models/vehicle_model.dart';

class TruckAvailabilityModel extends Equatable {
  const TruckAvailabilityModel({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.currentLocation,
    required this.availableFrom,
    required this.status,
    this.preferredDestination,
    this.note = '',
    this.vehicle,
    this.busy = false,
  });
  final String id, driverId, vehicleId, currentLocation, status, note;
  final DateTime availableFrom;
  final String? preferredDestination;
  final VehicleModel? vehicle;
  final bool busy;
  factory TruckAvailabilityModel.fromJson(Map<String, dynamic> json) {
    final vehicleJson = json['vehicle'];
    return TruckAvailabilityModel(
      id: json['id'],
      driverId: json['driver_id'],
      vehicleId: json['vehicle_id'],
      currentLocation: json['current_location'],
      availableFrom: DateTime.parse(json['available_from']),
      status: json['status'],
      busy: json['busy'] == true,
      preferredDestination: json['preferred_destination'],
      note: json['note'] ?? '',
      vehicle:
          vehicleJson is Map<String, dynamic> &&
              vehicleJson['registration_number'] != null
          ? VehicleModel.fromJson(vehicleJson)
          : null,
    );
  }
  @override
  List<Object?> get props => [
    id,
    vehicleId,
    currentLocation,
    availableFrom,
    status,
    preferredDestination,
    note,
    busy,
  ];
}

class AvailabilityDraft {
  const AvailabilityDraft({
    this.id,
    required this.vehicleId,
    required this.currentLocation,
    required this.availableFrom,
    this.preferredDestination,
    this.note = '',
    this.latitude,
    this.longitude,
  });
  final String? id;
  final String vehicleId, currentLocation, note;
  final DateTime availableFrom;
  final String? preferredDestination;
  final double? latitude, longitude;
  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicle_id': vehicleId,
    'current_location': currentLocation.trim(),
    'preferred_destination': preferredDestination?.trim(),
    'available_from': availableFrom.toUtc().toIso8601String(),
    'note': note.trim(),
    'latitude': latitude,
    'longitude': longitude,
  };
}
