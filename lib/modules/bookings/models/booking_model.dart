import 'package:equatable/equatable.dart';
import '../../loads/models/load_model.dart';

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
    this.reason,
    this.events = const [],
  });
  final String id, driverId, status, driverName, otherName, otherPhone;
  final String? reason;
  final LoadModel load;
  final DateTime createdAt;
  final DateTime? deliveryReportedAt;
  final List<BookingEvent> events;
  bool get canStart => status == 'accepted';
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
    reason: j['reason'],
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
    reason,
    events,
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
