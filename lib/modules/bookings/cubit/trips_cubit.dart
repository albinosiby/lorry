import 'package:lorry_link/core/state/resource_cubit.dart';
import '../models/booking_screen_models.dart';
import '../repositories/booking_repository_interface.dart';

class TripsCubit extends ResourceCubit<TripsScreenModel> {
  TripsCubit(this.repository);
  final IBookingRepository repository;
  String? _loadId, _status;
  Future<void> load({String? loadId, String? status}) {
    _loadId = loadId;
    _status = status;
    return fetch(() async {
      final rows = await repository.list(loadId: loadId, status: status);
      return TripsScreenModel(rows, rows.length == 20);
    });
  }

  Future<void> more() async {
    final prev = state.data;
    if (prev == null || !prev.hasMore || state.loading) return;
    await fetch(() async {
      final rows = await repository.list(
        loadId: _loadId,
        status: _status,
        offset: prev.bookings.length,
      );
      return TripsScreenModel([...prev.bookings, ...rows], rows.length == 20);
    });
  }
}
