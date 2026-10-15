import '../models/trip_location_model.dart';

abstract interface class ITripTrackingRepository {
  Future<TripLocationModel?> get(String bookingId);
  Future<void> update({
    required String bookingId,
    required double latitude,
    required double longitude,
  });
}
