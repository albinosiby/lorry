import 'dart:typed_data';
import 'package:equatable/equatable.dart';

enum DriverDocumentType {
  identity('identity', 'Aadhaar card', false),
  drivingLicense('driving_license', 'Driving licence', false),
  vehicleRegistration('vehicle_registration', 'Vehicle RC', true),
  insurance('insurance', 'Insurance', true),
  permit('permit', 'Transport permit', true),
  fitnessCertificate('fitness_certificate', 'Fitness certificate', true);

  const DriverDocumentType(this.databaseValue, this.label, this.needsVehicle);
  final String databaseValue, label;
  final bool needsVehicle;

  static DriverDocumentType fromDatabase(String value) => values.firstWhere(
    (type) => type.databaseValue == value,
    orElse: () => DriverDocumentType.identity,
  );
}

class DriverDocumentModel extends Equatable {
  const DriverDocumentModel({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.vehicleId,
    this.storagePath,
    this.expiresOn,
    this.rejectionReason,
  });

  final String id, status;
  final DriverDocumentType type;
  final DateTime createdAt;
  final String? vehicleId, storagePath, rejectionReason;
  final DateTime? expiresOn;

  bool get isExpired =>
      expiresOn != null && expiresOn!.isBefore(DateTime.now());
  bool get expiresSoon =>
      expiresOn != null &&
      !isExpired &&
      expiresOn!.isBefore(DateTime.now().add(const Duration(days: 30)));

  factory DriverDocumentModel.fromJson(Map<String, dynamic> json) =>
      DriverDocumentModel(
        id: json['id'].toString(),
        type: DriverDocumentType.fromDatabase(
          json['document_type']?.toString() ?? 'identity',
        ),
        status: json['status']?.toString() ?? 'submitted',
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        vehicleId: json['vehicle_id']?.toString(),
        storagePath: json['storage_path']?.toString(),
        expiresOn: json['expires_on'] == null
            ? null
            : DateTime.tryParse(json['expires_on'].toString()),
        rejectionReason: json['rejection_reason']?.toString(),
      );

  DriverDocumentModel copyWith({
    String? id,
    DriverDocumentType? type,
    String? status,
    DateTime? createdAt,
    String? vehicleId,
    String? storagePath,
    DateTime? expiresOn,
    String? rejectionReason,
  }) => DriverDocumentModel(
    id: id ?? this.id,
    type: type ?? this.type,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    vehicleId: vehicleId ?? this.vehicleId,
    storagePath: storagePath ?? this.storagePath,
    expiresOn: expiresOn ?? this.expiresOn,
    rejectionReason: rejectionReason ?? this.rejectionReason,
  );

  @override
  List<Object?> get props => [
    id,
    type,
    status,
    createdAt,
    vehicleId,
    storagePath,
    expiresOn,
    rejectionReason,
  ];
}

class DriverDocumentDraft {
  const DriverDocumentDraft({
    required this.type,
    required this.bytes,
    required this.filename,
    required this.contentType,
    this.vehicleId,
    this.expiresOn,
  });

  final DriverDocumentType type;
  final Uint8List bytes;
  final String filename, contentType;
  final String? vehicleId;
  final DateTime? expiresOn;
}
