import '../models/booking_model.dart';

abstract interface class IBookingRepository {
  Future<void> callContact(String phone);
  Future<String> request(String loadId, {String? vehicleId});
  Future<void> recordPayment(
    String id,
    double amount, {
    required String requestId,
    double? agreedFreight,
  });
  Future<void> assignTruck(String id, String vehicleId);
  Future<void> markStopUnloaded(String id, int index);
  Future<void> reportIssue(String id, String reason);
  Future<List<BookingModel>> list({
    bool incoming = false,
    String? loadId,
    String? status,
    int offset = 0,
  });
  Future<BookingModel> get(String id);
  Future<void> transition(
    String id,
    String status, {
    String? reason,
    double? collectedAmount,
    double? latitude,
    double? longitude,
  });
  Future<void> acceptCustomerInvitation(String id);
}
