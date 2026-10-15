import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../utils/services/location_service.dart';
import '../../bookings/models/booking_model.dart';
import '../../bookings/repositories/booking_repository_interface.dart';
import '../models/home_model.dart';
import '../repositories/home_repository_interface.dart';

class HomeCubit extends ResourceCubit<HomeModel> {
  HomeCubit(this.repository, this.bookings, this.locationService);
  final IHomeRepository repository;
  final IBookingRepository bookings;
  final ILocationService locationService;

  Future<void> load({bool includeDriverTools = false}) => fetch(() async {
    final home = await repository.get();
    final inTransit = await bookings.list(status: 'in_transit');
    if (!includeDriverTools) {
      return home.copyWith(ongoingTrips: inTransit);
    }
    final results = await Future.wait([
      bookings.list(status: 'accepted'),
      _readLocation(),
    ]);
    return home.copyWith(
      acceptedTrips: results[0] as List<BookingModel>,
      ongoingTrips: inTransit,
      driverLocation: results[1] as DeviceLocation?,
    );
  });

  Future<void> requestDriverLocation() async {
    final home = state.data;
    if (home == null || state.busy) return;
    emit(ResourceState(data: home, busy: true));
    final location = await _readLocation(requestPermission: true);
    if (!isClosed) {
      emit(ResourceState(data: home.copyWith(driverLocation: location)));
    }
  }

  Future<void> openLocationSettings(DeviceLocationStatus? status) =>
      status == DeviceLocationStatus.serviceDisabled
      ? locationService.openSettings()
      : locationService.openAppSettings();

  Future<DeviceLocation?> _readLocation({
    bool requestPermission = false,
  }) async {
    try {
      return await locationService.current(
        requestPermission: requestPermission,
      );
    } catch (_) {
      return null;
    }
  }
}
