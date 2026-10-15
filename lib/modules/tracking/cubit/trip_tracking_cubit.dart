import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../utils/services/location_service.dart';
import '../models/trip_location_model.dart';
import '../repositories/trip_tracking_repository_interface.dart';

class TripTrackingCubit extends ResourceCubit<TripLocationModel?> {
  TripTrackingCubit(this.repository, this.locationService);
  final ITripTrackingRepository repository;
  final ILocationService locationService;

  Future<void> load(String bookingId) => fetch(() => repository.get(bookingId));

  Future<bool> shareCurrentLocation(String bookingId) async {
    final updated = await act(() async {
      final location = await locationService.current();
      if (!location.available) {
        throw StateError(
          'Turn on location permission to share your trip position.',
        );
      }
      await repository.update(
        bookingId: bookingId,
        latitude: location.latitude!,
        longitude: location.longitude!,
      );
    }, notice: 'Live trip location updated.');
    if (updated) await load(bookingId);
    return updated;
  }
}
