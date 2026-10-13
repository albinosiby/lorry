import '../models/booking_model.dart';

abstract interface class IBookingRepository {
  Future<void> callContact(String phone);
  Future<String> request(String loadId);
  Future<List<BookingModel>> list({
    String? loadId,
    String? status,
    int offset = 0,
  });
  Future<BookingModel> get(String id);
  Future<void> transition(String id, String status, {String? reason});
}
