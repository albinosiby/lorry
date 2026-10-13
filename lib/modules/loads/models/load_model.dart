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
    this.bookingId,
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
  final String? bookingId;
  final int requestCount;
  String get pickupLabel => placeLabel(pickup);
  String get destinationLabel => placeLabel(destination);
  String get dateLabel => DateFormat('d MMM yyyy').format(pickupDate);
  String get priceLabel => price == null
      ? 'Price on discussion'
      : NumberFormat.currency(
          name: currency,
          symbol: currency == 'INR' ? '₹' : currency,
          decimalDigits: 0,
        ).format(price);
  factory LoadModel.fromJson(Map<String, dynamic> j) => LoadModel(
    id: j['id'],
    shipperId: j['shipper_id'],
    pickup: j['pickup'],
    destination: j['destination'],
    cargo: j['cargo'],
    vehicle: j['vehicle'],
    pickupDate: DateTime.parse(j['pickup_date']),
    status: j['status'],
    price: (j['price'] as num?)?.toDouble(),
    currency: j['currency'] ?? 'INR',
    contactPreference: j['contact_preference'],
    bookingId: j['booking_id'],
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
    requestCount,
    bookingId,
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
  const LoadFilter({this.pickup, this.destination, this.vehicle, this.status});
  final String? pickup, destination, vehicle, status;
  Map<String, dynamic> toJson() => {
    'pickup': pickup,
    'destination': destination,
    'vehicle': vehicle,
    'status': status,
  };
  @override
  List<Object?> get props => [pickup, destination, vehicle, status];
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
  });
  final String id, pickup, destination, cargo, vehicle, contactPreference;
  final DateTime date;
  final double? price;
  Map<String, dynamic> toJson() => {
    'id': id,
    'pickup': pickup,
    'destination': destination,
    'cargo': cargo.trim(),
    'vehicle': vehicle,
    'pickup_date': DateFormat('yyyy-MM-dd').format(date),
    'price': price,
    'contact_preference': contactPreference,
  };
}
