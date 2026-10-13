import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../bookings/repositories/booking_repository_interface.dart';
import '../models/load_screen_models.dart';
import '../repositories/load_repository_interface.dart';

class LoadDetailsCubit extends ResourceCubit<LoadDetailsModel> {
  LoadDetailsCubit(this.repository, this.bookings);
  final ILoadRepository repository;
  final IBookingRepository bookings;
  Future<bool> callContact(String phone) =>
      act(() => repository.callContact(phone));
  Future<void> load(String id) => fetch(() => repository.get(id));
  Future<bool> cancel(String id) =>
      act(() => repository.cancel(id), notice: 'Load cancelled.');
  String? requestedBookingId;
  Future<bool> request(String id) => act(() async {
    requestedBookingId = await bookings.request(id);
  }, notice: 'Booking requested.');
}
