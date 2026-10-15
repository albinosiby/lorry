import '../../loads/models/load_model.dart';
import '../../bookings/models/booking_model.dart';
import '../../../utils/services/location_service.dart';

class HomeModel {
  const HomeModel({
    required this.open,
    required this.active,
    required this.completed,
    required this.pending,
    required this.unread,
    required this.loads,
    this.acceptedTrips = const [],
    this.ongoingTrips = const [],
    this.driverLocation,
  });
  final int open, active, completed, pending, unread;
  final List<LoadModel> loads;
  final List<BookingModel> acceptedTrips;
  final List<BookingModel> ongoingTrips;
  final DeviceLocation? driverLocation;
  factory HomeModel.fromJson(Map<String, dynamic> j) => HomeModel(
    open: j['open_count'],
    active: j['active_count'],
    completed: j['completed_count'],
    pending: j['pending_count'],
    unread: j['unread_count'],
    loads: (j['loads'] as List).map((l) => LoadModel.fromJson(l)).toList(),
  );

  HomeModel copyWith({
    List<BookingModel>? acceptedTrips,
    List<BookingModel>? ongoingTrips,
    DeviceLocation? driverLocation,
  }) => HomeModel(
    open: open,
    active: active,
    completed: completed,
    pending: pending,
    unread: unread,
    loads: loads,
    acceptedTrips: acceptedTrips ?? this.acceptedTrips,
    ongoingTrips: ongoingTrips ?? this.ongoingTrips,
    driverLocation: driverLocation ?? this.driverLocation,
  );
}
