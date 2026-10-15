import '../../../utils/services/supabase_service.dart';
import '../models/trip_location_model.dart';
import 'trip_tracking_repository_interface.dart';

class TripTrackingRepository implements ITripTrackingRepository {
  TripTrackingRepository(this.service);
  final SupabaseService service;
  @override
  Future<TripLocationModel?> get(String bookingId) async {
    final row = await service.callCustomer('tracking.get', {
      'booking_id': bookingId,
    });
    if (row == null) return null;
    final data = Map<String, dynamic>.from(row);
    return data.isEmpty ? null : TripLocationModel.fromJson(data);
  }

  @override
  Future<void> update({
    required String bookingId,
    required double latitude,
    required double longitude,
  }) => service.callCustomer('tracking.update', {
    'booking_id': bookingId,
    'latitude': latitude,
    'longitude': longitude,
    'recorded_at': DateTime.now().toUtc().toIso8601String(),
  });
}
