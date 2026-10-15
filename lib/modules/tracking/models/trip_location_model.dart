import 'package:equatable/equatable.dart';

class TripLocationModel extends Equatable {
  const TripLocationModel({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracyMeters,
    this.locationEnabled = true,
  });
  final double latitude, longitude;
  final DateTime recordedAt;
  final double? accuracyMeters;
  final bool locationEnabled;
  bool get stale =>
      DateTime.now().toUtc().difference(recordedAt.toUtc()) >
      const Duration(minutes: 5);

  factory TripLocationModel.fromJson(Map<String, dynamic> json) =>
      TripLocationModel(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        recordedAt: DateTime.parse(json['recorded_at'].toString()),
        accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
        locationEnabled: json['location_enabled'] != false,
      );
  @override
  List<Object?> get props => [
    latitude,
    longitude,
    recordedAt,
    accuracyMeters,
    locationEnabled,
  ];
}
