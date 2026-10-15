import 'package:equatable/equatable.dart';

class VehicleModel extends Equatable {
  const VehicleModel({
    required this.id,
    required this.registrationNumber,
    required this.vehicleType,
    required this.bodyType,
    required this.lengthFt,
    required this.capacityTonnes,
    required this.isDefault,
  });
  final String id, registrationNumber, vehicleType, bodyType;
  final double lengthFt, capacityTonnes;
  final bool isDefault;

  factory VehicleModel.fromJson(Map<String, dynamic> json) => VehicleModel(
    id: json['id'],
    registrationNumber:
        json['registration_number'] ?? json['registration_label'] ?? 'Private',
    vehicleType: json['vehicle_type'],
    bodyType: json['body_type'] ?? json['vehicle_type'],
    lengthFt: (json['length_ft'] as num).toDouble(),
    capacityTonnes: (json['capacity_tonnes'] as num).toDouble(),
    isDefault: json['is_default'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [
    id,
    registrationNumber,
    vehicleType,
    lengthFt,
    capacityTonnes,
    isDefault,
  ];
}

class VehicleDraft {
  const VehicleDraft({
    this.id,
    required this.registrationNumber,
    required this.vehicleType,
    required this.bodyType,
    required this.lengthFt,
    required this.capacityTonnes,
    this.isDefault = false,
  });
  final String? id;
  final String registrationNumber, vehicleType, bodyType;
  final double lengthFt, capacityTonnes;
  final bool isDefault;
  Map<String, dynamic> toJson() => {
    'id': id,
    'registration_number': registrationNumber.trim().toUpperCase(),
    'vehicle_type': vehicleType,
    'body_type': bodyType,
    'length_ft': lengthFt,
    'capacity_tonnes': capacityTonnes,
    'is_default': isDefault,
  };
}
