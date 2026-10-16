import '../../../utils/services/contact_service.dart';
import '../../../utils/services/supabase_service.dart';
import '../models/booking_model.dart';
import 'booking_repository_interface.dart';

class BookingRepository implements IBookingRepository {
  BookingRepository(this.service);
  final SupabaseService service;
  @override
  Future<void> callContact(String phone) => ContactService().call(phone);
  @override
  Future<String> request(String loadId, {String? vehicleId}) async =>
      (await service.call('bookings.request', {
        'load_id': loadId,
        'vehicle_id': vehicleId,
      }))['id'];
  @override
  Future<void> recordPayment(
    String id,
    double amount, {
    required String requestId,
    double? agreedFreight,
  }) async {
    await service.call('bookings.payment', {
      'id': id,
      'amount_collected': amount,
      'payment_id': requestId,
      'agreed_freight': agreedFreight,
    });
  }

  @override
  Future<void> assignTruck(String id, String vehicleId) async {
    await service.call('bookings.assign_truck', {
      'id': id,
      'vehicle_id': vehicleId,
    });
  }

  @override
  Future<void> markStopUnloaded(String id, int index) async {
    await service.call('bookings.stop_unloaded', {
      'id': id,
      'stop_index': index,
    });
  }

  @override
  Future<void> reportIssue(String id, String reason) async {
    await service.call('bookings.delivery_issue', {'id': id, 'reason': reason});
  }

  @override
  Future<List<BookingModel>> list({
    bool incoming = false,
    String? loadId,
    String? status,
    int offset = 0,
  }) async =>
      (await service.call('bookings.list', {
                'incoming': incoming,
                'load_id': loadId,
                'status': status,
                'offset': offset,
              })
              as List)
          .map((j) => BookingModel.fromJson(j))
          .toList();
  @override
  Future<BookingModel> get(String id) async =>
      BookingModel.fromJson(await service.call('bookings.get', {'id': id}));
  @override
  Future<void> transition(
    String id,
    String status, {
    String? reason,
    double? collectedAmount,
    double? latitude,
    double? longitude,
  }) async {
    await service.call('bookings.transition', {
      'id': id,
      'status': status,
      'reason': reason,
      'amount_collected': collectedAmount,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  @override
  Future<void> acceptCustomerInvitation(String id) =>
      service.callCustomer('customer.invitation.accept', {'booking_id': id});
}
