import 'package:equatable/equatable.dart';
import '../../loads/models/load_model.dart';
import '../../vehicles/models/vehicle_model.dart';

class BookingModel extends Equatable {
  const BookingModel({
    required this.id,
    required this.driverId,
    required this.status,
    required this.load,
    required this.createdAt,
    this.driverName = '',
    this.otherName = '',
    this.otherPhone = '',
    this.deliveryReportedAt,
    this.itemCollectedAt,
    this.reason,
    this.source = 'driver_request',
    this.events = const [],
    this.vehicle,
    this.vehicleId,
    this.agreedFreight,
    this.amountCollected = 0,
    this.unloadedStopIndices = const [],
    this.deliveryIssue,
  });
  final String id, driverId, status, driverName, otherName, otherPhone, source;
  final String? reason;
  final LoadModel load;
  final DateTime createdAt;
  final DateTime? deliveryReportedAt;
  final DateTime? itemCollectedAt;
  final List<BookingEvent> events;
  final VehicleModel? vehicle;
  final String? vehicleId, deliveryIssue;
  final double? agreedFreight;
  final double amountCollected;
  final List<int> unloadedStopIndices;
  double? get freight => agreedFreight ?? load.price;
  double? get balance => freight == null
      ? null
      : (freight! - amountCollected).clamp(0, double.infinity);
  String get paymentLabel => freight == null
      ? 'Freight not agreed'
      : balance == 0
      ? 'Paid'
      : amountCollected > 0
      ? 'Partially paid'
      : 'Unpaid';
  bool get canRecordPayment =>
      deliveryReportedAt != null &&
      (status == 'in_transit' || status == 'completed') &&
      (balance == null || balance! > 0);
  String get displayStatus => status == 'completed'
      ? 'delivery_confirmed'
      : deliveryPendingConfirmation
      ? 'delivery_reported'
      : status == 'accepted' && itemsCollected
      ? 'item_collected'
      : status;
  bool get deliveryPendingConfirmation =>
      status == 'in_transit' && deliveryReportedAt != null;
  bool get isLiveTrip => status == 'in_transit' && deliveryReportedAt == null;
  bool get itemsCollected =>
      itemCollectedAt != null ||
      status == 'in_transit' ||
      status == 'completed';
  bool get canCollect => status == 'accepted' && !itemsCollected;
  bool get canStart => status == 'accepted' && itemsCollected;
  bool get canReport => status == 'in_transit' && deliveryReportedAt == null;
  bool get canComplete => status == 'in_transit' && deliveryReportedAt != null;
  bool get canCancel => status == 'requested' || status == 'accepted';
  factory BookingModel.fromJson(Map<String, dynamic> j) => BookingModel(
    id: j['id'],
    driverId: j['driver_id'],
    status: j['status'],
    load: LoadModel.fromJson(j['load']),
    createdAt: DateTime.parse(j['created_at']),
    driverName: j['driver_name'] ?? '',
    otherName: j['other_name'] ?? '',
    otherPhone: j['other_phone'] ?? '',
    deliveryReportedAt: DateTime.tryParse(j['delivery_reported_at'] ?? ''),
    itemCollectedAt: DateTime.tryParse(j['item_collected_at'] ?? ''),
    reason: j['reason'],
    source: j['source'] ?? 'driver_request',
    vehicleId: j['vehicle_id'],
    vehicle: j['assigned_vehicle'] is Map
        ? VehicleModel.fromJson(
            Map<String, dynamic>.from(j['assigned_vehicle']),
          )
        : null,
    agreedFreight: (j['agreed_freight'] as num?)?.toDouble(),
    amountCollected: (j['amount_collected'] as num?)?.toDouble() ?? 0,
    unloadedStopIndices: (j['unloaded_stop_indices'] as List? ?? const [])
        .map((i) => (i as num).toInt())
        .toList(),
    deliveryIssue: j['delivery_issue'],
    events: ((j['events'] as List?) ?? [])
        .map((e) => BookingEvent.fromJson(e))
        .toList(),
  );
  @override
  List<Object?> get props => [
    id,
    status,
    load,
    deliveryReportedAt,
    itemCollectedAt,
    reason,
    events,
    source,
    vehicle,
    vehicleId,
    agreedFreight,
    amountCollected,
    unloadedStopIndices,
    deliveryIssue,
  ];
}

class BookingEvent extends Equatable {
  const BookingEvent(this.status, this.at, this.note);
  final String status, note;
  final DateTime at;
  factory BookingEvent.fromJson(Map<String, dynamic> j) => BookingEvent(
    j['status'],
    DateTime.parse(j['created_at']),
    j['note'] ?? '',
  );
  @override
  List<Object?> get props => [status, at, note];
}
