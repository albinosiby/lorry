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
  Future<String> request(String loadId) async =>
      (await service.call('bookings.request', {'load_id': loadId}))['id'];
  @override
  Future<List<BookingModel>> list({
    String? loadId,
    String? status,
    int offset = 0,
  }) async =>
      (await service.call('bookings.list', {
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
