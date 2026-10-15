import 'package:equatable/equatable.dart';

class TripLocationModel extends Equatable {
  const TripLocationModel({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracyMeters,
  });
  final double latitude, longitude;
  final DateTime recordedAt;
  final double? accuracyMeters;

  factory TripLocationModel.fromJson(Map<String, dynamic> json) =>
      TripLocationModel(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        recordedAt: DateTime.parse(json['recorded_at'].toString()),
        accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
      );
  @override
  List<Object?> get props => [latitude, longitude, recordedAt, accuracyMeters];
}
