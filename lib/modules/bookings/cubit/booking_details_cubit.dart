import 'package:lorry_link/core/state/resource_cubit.dart';
import '../models/booking_screen_models.dart';
import '../repositories/booking_repository_interface.dart';

class BookingDetailsCubit extends ResourceCubit<BookingDetailsModel> {
  BookingDetailsCubit(this.repository);
  final IBookingRepository repository;
  Future<bool> callContact(String phone) =>
      act(() => repository.callContact(phone));
  Future<void> load(String id) =>
      fetch(() async => BookingDetailsModel(await repository.get(id)));
  Future<bool> transition(String id, String status, {String? reason}) => act(
    () => repository.transition(id, status, reason: reason),
    notice: 'Booking updated.',
  );
}
