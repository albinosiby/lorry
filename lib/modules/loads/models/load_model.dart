import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

const vehicleTypes = [
  'Mini truck',
  'Pickup',
  'LCV',
  'Open truck',
  'Container',
  'Trailer',
  'Refrigerated',
];
const vehicleLengthOptions = ['10', '12', '14', '16', '20', '22', '24', '32'];
String statusLabel(String value) => switch (value) {
  'in_transit' => 'In transit',
  'delivery_reported' => 'Delivery reported',
  _ => value.isEmpty ? '' : '${value[0].toUpperCase()}${value.substring(1)}',
};

class LoadModel extends Equatable {
  const LoadModel({
    required this.id,
    required this.shipperId,
    required this.pickup,
    required this.destination,
    required this.cargo,
    required this.vehicle,
    required this.pickupDate,
    required this.status,
    this.price,
    this.currency = 'INR',
    this.contactPreference = 'after_acceptance',
    this.weightTonnes = 1,
    this.requiredVehicleLengthFt,
    this.pickupAt,
    this.specialNote = '',
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.bookingId,
    this.deliveryReportedAt,
    this.unloadStops = const [],
    this.requestCount = 0,
  });
  final String id,
      shipperId,
      pickup,
      destination,
      cargo,
      vehicle,
      status,
      currency,
      contactPreference;
  final DateTime pickupDate;
  final double? price;
  final double weightTonnes;
  final double? requiredVehicleLengthFt;
  final DateTime? pickupAt;
  final String specialNote;
  final double? pickupLatitude,
      pickupLongitude,
      destinationLatitude,
      destinationLongitude;
  final String? bookingId;
  final DateTime? deliveryReportedAt;
  final List<UnloadStop> unloadStops;
  final int requestCount;
  String get pickupLabel => placeLabel(pickup);
  String get destinationLabel => placeLabel(destination);
  String get dateLabel => DateFormat('d MMM yyyy').format(pickupDate);
  String get pickupScheduleLabel => pickupAt == null
      ? '$dateLabel · Flexible time'
      : DateFormat('d MMM, h:mm a').format(pickupAt!.toLocal());
  String get weightLabel =>
      '${weightTonnes.toStringAsFixed(weightTonnes.truncateToDouble() == weightTonnes ? 0 : 1)} t';
  String get vehicleLengthLabel => requiredVehicleLengthFt == null
      ? 'Any length'
      : '${requiredVehicleLengthFt!.toStringAsFixed(requiredVehicleLengthFt!.truncateToDouble() == requiredVehicleLengthFt ? 0 : 1)} ft';
  bool get hasPickupCoordinates =>
      pickupLatitude != null && pickupLongitude != null;
  bool get hasDestinationCoordinates =>
      destinationLatitude != null && destinationLongitude != null;
  String get displayStatus =>
      status == 'in_transit' && deliveryReportedAt != null
      ? 'delivery_reported'
      : status;
  String get priceLabel => price == null
      ? 'Price on discussion'
      : NumberFormat.currency(
          name: currency,
          symbol: currency == 'INR' ? '₹' : currency,
          decimalDigits: 0,
        ).format(price);
  factory LoadModel.fromJson(Map<String, dynamic> j) => LoadModel(
    id: j['id']?.toString() ?? '',
    shipperId: j['shipper_id']?.toString() ?? '',
    pickup: j['pickup']?.toString().trim().isNotEmpty == true
        ? j['pickup'].toString()
        : 'Pickup location pending',
    destination: j['destination']?.toString().trim().isNotEmpty == true
        ? j['destination'].toString()
        : 'Destination pending',
    cargo: j['cargo']?.toString().trim().isNotEmpty == true
        ? j['cargo'].toString()
        : 'Cargo details pending',
    vehicle: j['vehicle']?.toString().trim().isNotEmpty == true
        ? j['vehicle'].toString()
        : 'Compatible vehicle',
    pickupDate:
        DateTime.tryParse(j['pickup_date']?.toString() ?? '') ?? DateTime.now(),
    status: j['status']?.toString() ?? 'open',
    price: (j['price'] as num?)?.toDouble(),
    currency: j['currency'] ?? 'INR',
    contactPreference:
        j['contact_preference']?.toString() ?? 'after_acceptance',
    weightTonnes: (j['weight_tonnes'] as num?)?.toDouble() ?? 1,
    requiredVehicleLengthFt: (j['required_vehicle_length_ft'] as num?)
        ?.toDouble(),
    pickupAt: j['pickup_at'] == null
        ? null
        : DateTime.tryParse(j['pickup_at'].toString()),
    specialNote: j['special_note'] ?? '',
    pickupLatitude: (j['pickup_latitude'] as num?)?.toDouble(),
    pickupLongitude: (j['pickup_longitude'] as num?)?.toDouble(),
    destinationLatitude: (j['destination_latitude'] as num?)?.toDouble(),
    destinationLongitude: (j['destination_longitude'] as num?)?.toDouble(),
    bookingId: j['booking_id'],
    deliveryReportedAt: j['delivery_reported_at'] == null
        ? null
        : DateTime.tryParse(j['delivery_reported_at'].toString()),
    unloadStops: ((j['unload_stops'] as List?) ?? const [])
        .whereType<Map>()
        .map((stop) => UnloadStop.fromJson(Map<String, dynamic>.from(stop)))
        .toList(),
    requestCount: (j['request_count'] as num?)?.toInt() ?? 0,
  );
  @override
  List<Object?> get props => [
    id,
    status,
    cargo,
    pickup,
    destination,
    vehicle,
    pickupDate,
    price,
    weightTonnes,
    requiredVehicleLengthFt,
    pickupAt,
    specialNote,
    pickupLatitude,
    pickupLongitude,
    destinationLatitude,
    destinationLongitude,
    requestCount,
    bookingId,
    deliveryReportedAt,
    unloadStops,
  ];
}

String placeLabel(String value) => value
    .trim()
    .split(RegExp(r'\s+'))
    .map(
      (word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
    )
    .join(' ');

class LoadFilter extends Equatable {
  const LoadFilter({
    this.pickup,
    this.destination,
    this.vehicle,
    this.status,
    this.maxWeightTonnes,
    this.minVehicleLengthFt,
  });
  final String? pickup, destination, vehicle, status;
  final double? maxWeightTonnes, minVehicleLengthFt;
  Map<String, dynamic> toJson() => {
    'pickup': pickup,
    'destination': destination,
    'vehicle': vehicle,
    'status': status,
    'max_weight_tonnes': maxWeightTonnes,
    'min_vehicle_length_ft': minVehicleLengthFt,
  };

  /// A defensive client-side fit check. The database applies the same rules,
  /// but this keeps the driver marketplace correct when a legacy response or
  /// cached page contains a load outside the selected truck limits.
  bool matchesTruckFit(LoadModel load) =>
      (vehicle == null || load.vehicle == vehicle) &&
      (maxWeightTonnes == null || load.weightTonnes <= maxWeightTonnes!) &&
      (minVehicleLengthFt == null ||
          (load.requiredVehicleLengthFt ?? 0) <= minVehicleLengthFt!);
  @override
  List<Object?> get props => [
    pickup,
    destination,
    vehicle,
    status,
    maxWeightTonnes,
    minVehicleLengthFt,
  ];
}

class LoadDraft {
  const LoadDraft({
    required this.id,
    required this.pickup,
    required this.destination,
    required this.cargo,
    required this.vehicle,
    required this.date,
    this.price,
    this.contactPreference = 'after_acceptance',
    this.weightTonnes = 1,
    this.requiredVehicleLengthFt,
    this.pickupAt,
    this.specialNote = '',
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.unloadStops = const [],
  });
  final String id, pickup, destination, cargo, vehicle, contactPreference;
  final DateTime date;
  final double? price;
  final double weightTonnes;
  final double? requiredVehicleLengthFt;
  final DateTime? pickupAt;
  final String specialNote;
  final double? pickupLatitude,
      pickupLongitude,
      destinationLatitude,
      destinationLongitude;
  final List<UnloadStop> unloadStops;
  Map<String, dynamic> toJson() => {
    'id': id,
    'pickup': pickup,
    'destination': destination,
    'cargo': cargo.trim(),
    'vehicle': vehicle,
    'pickup_date': DateFormat('yyyy-MM-dd').format(date),
    'price': price,
    'contact_preference': contactPreference,
    'weight_tonnes': weightTonnes,
    'required_vehicle_length_ft': requiredVehicleLengthFt,
    'pickup_at': pickupAt?.toUtc().toIso8601String(),
    'special_note': specialNote.trim(),
    'pickup_latitude': pickupLatitude,
    'pickup_longitude': pickupLongitude,
    'destination_latitude': destinationLatitude,
    'destination_longitude': destinationLongitude,
    'unload_stops': unloadStops.map((stop) => stop.toJson()).toList(),
  };
}

class UnloadStop extends Equatable {
  const UnloadStop({
    required this.location,
    this.unloadTonnes,
    this.latitude,
    this.longitude,
  });

  final String location;
  final double? unloadTonnes;
  final double? latitude, longitude;

  factory UnloadStop.fromJson(Map<String, dynamic> json) => UnloadStop(
    location: json['location']?.toString().trim() ?? '',
    unloadTonnes: (json['unload_tonnes'] as num?)?.toDouble(),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'location': location.trim(),
    if (unloadTonnes != null) 'unload_tonnes': unloadTonnes,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  @override
  List<Object?> get props => [location, unloadTonnes, latitude, longitude];
}
