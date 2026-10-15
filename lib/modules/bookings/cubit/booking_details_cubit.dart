import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../utils/exceptions/app_exception.dart';
import '../../../utils/services/location_service.dart';
import '../models/booking_screen_models.dart';
import '../repositories/booking_repository_interface.dart';

class BookingDetailsCubit extends ResourceCubit<BookingDetailsModel> {
  BookingDetailsCubit(
    this.repository,
    this.locationService, {
    this.onTripStarted,
  });
  final Future<void> Function()? onTripStarted;
  final IBookingRepository repository;
  final ILocationService locationService;
  Future<bool> callContact(String phone) =>
      act(() => repository.callContact(phone));
  Future<void> load(String id) =>
      fetch(() async => BookingDetailsModel(await repository.get(id)));
  Future<bool> transition(String id, String status, {String? reason}) => act(
    () => repository.transition(id, status, reason: reason),
    notice: 'Booking updated.',
  );

  Future<bool> reportDeliveryWithCollection(String id, double amount) =>
      act(() async {
        await repository.transition(
          id,
          'delivery_reported',
          collectedAmount: amount,
        );
        final updated = await repository.get(id);
        if (!isClosed) {
          emit(ResourceState(data: BookingDetailsModel(updated), busy: true));
        }
      }, notice: 'Delivery reported. Freight income was added to Finance.');

  /// Requests GPS access before any booking request is sent. This keeps a
  /// phone permission/service problem distinct from a backend connection error.
  Future<DeviceLocation?> requestLocationForTrip() async {
    if (isClosed || state.busy) return null;
    final data = state.data;
    emit(ResourceState(data: data, busy: true));
    try {
      final location = await locationService.current();
      if (!location.available) {
        throw AppException(_locationMessage(location.status));
      }
      if (!isClosed) emit(ResourceState(data: data));
      return location;
    } catch (error) {
      if (!isClosed) {
        emit(
          ResourceState(data: data, error: AppException.from(error).message),
        );
      }
      return null;
    }
  }

  String _locationMessage(DeviceLocationStatus status) => switch (status) {
    DeviceLocationStatus.serviceDisabled =>
      'Turn on GPS/location services, then start the trip again.',
    DeviceLocationStatus.permissionDenied =>
      'Allow location access to start the trip and share the truck position.',
    DeviceLocationStatus.permissionDeniedForever =>
      'Location access is blocked. Enable it for LORRY LINK in your phone settings, then try again.',
    DeviceLocationStatus.ready => '',
  };

  /// Starting the booking and saving its first GPS point happen in one server
  /// transaction, so a customer never sees an active but untrackable trip.
  Future<bool> startTripWithLocation(String id, DeviceLocation location) =>
      act(() async {
        await repository.transition(
          id,
          'in_transit',
          latitude: location.latitude!,
          longitude: location.longitude!,
        );
        await onTripStarted?.call();
      }, notice: 'Trip started and your first location was shared.');

  Future<bool> collectItems(String id, DeviceLocation location) => act(
    () => repository.transition(
      id,
      'item_collected',
      latitude: location.latitude!,
      longitude: location.longitude!,
    ),
    notice: 'Items collected. Your customer has been notified.',
  );
  Future<bool> acceptCustomerInvitation(String id) => act(
    () => repository.acceptCustomerInvitation(id),
    notice: 'Truck invitation accepted.',
  );
  Future<bool> reRequest(String loadId) => act(
    () => repository.request(loadId),
    notice: 'Booking request resubmitted.',
  );
}
