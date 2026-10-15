import 'package:equatable/equatable.dart';

enum NearbyServiceType {
  fuel('Fuel pump', 'fuel'),
  truckStop('Truck lay-by', 'truck_stop'),
  weighbridge('Weighbridge', 'weighbridge'),
  workshop('Workshop', 'workshop'),
  tyre('Tyre work', 'tyre'),
  hospital('Hospital', 'hospital'),
  food('Food / dhabas', 'food'),
  hotel('Hotels / stays', 'hotel'),
  serviceCenter('Service centres', 'service_center');

  const NearbyServiceType(this.label, this.apiValue);
  final String label;
  final String apiValue;
}

class NearbyServiceModel extends Equatable {
  const NearbyServiceModel({
    required this.id,
    required this.type,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.distanceKm,
    this.rating,
    this.openNow,
    this.phone = '',
    this.provider = '',
    this.openingHours = '',
    this.truckFriendly = false,
    this.attributions = const [],
  });

  final String id, name, address;
  final NearbyServiceType type;
  final double latitude, longitude;
  final double? distanceKm, rating;
  final bool? openNow;
  final String phone, provider, openingHours;
  final bool truckFriendly;
  final List<Map<String, dynamic>> attributions;

  factory NearbyServiceModel.fromJson(Map<String, dynamic> json) {
    final apiType = json['service_type'] ?? json['type'] ?? 'fuel';
    return NearbyServiceModel(
      id: json['id'] ?? json['place_id'] ?? json['provider_place_id'] ?? '',
      type: NearbyServiceType.values.firstWhere(
        (item) => item.apiValue == apiType,
        orElse: () => NearbyServiceType.fuel,
      ),
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      openNow: json['is_open_now'] as bool?,
      phone: json['phone']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      openingHours: json['opening_hours']?.toString() ?? '',
      truckFriendly: json['truck_friendly'] == true,
      attributions: (json['attributions'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    name,
    latitude,
    longitude,
    distanceKm,
    rating,
    openNow,
    phone,
    provider,
    openingHours,
    truckFriendly,
    attributions,
  ];
}
