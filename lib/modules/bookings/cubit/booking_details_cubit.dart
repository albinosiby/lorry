import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../utils/exceptions/app_exception.dart';
import '../../../utils/services/location_service.dart';
import '../models/booking_screen_models.dart';
import '../repositories/booking_repository_interface.dart';
import '../../../utils/services/payment_request_store.dart';
import '../../vehicles/repositories/vehicle_repository_interface.dart';
import '../../vehicles/models/vehicle_model.dart';
import '../../loads/models/load_model.dart';

class BookingDetailsCubit extends ResourceCubit<BookingDetailsModel> {
  BookingDetailsCubit(
    this.repository,
    this.locationService, {
    this.onTripStarted,
    this.vehicles,
    IPaymentRequestStore? paymentRequests,
  }) : paymentRequests = paymentRequests ?? MemoryPaymentRequestStore();
  final Future<void> Function()? onTripStarted;
  final IBookingRepository repository;
  final ILocationService locationService;
  final IVehicleRepository? vehicles;
  final IPaymentRequestStore paymentRequests;
  bool _preparingPayment = false;
  String? _refreshRequiredFor;
  Future<List<VehicleModel>> matchingTrucks(LoadModel load) async =>
      (await vehicles?.list() ?? <VehicleModel>[])
          .where(
            (v) =>
                v.capacityTonnes >= load.weightTonnes &&
                v.lengthFt >= (load.requiredVehicleLengthFt ?? 0) &&
                vehicleTypeFitsLoad(v.vehicleType, v.bodyType, load.vehicle),
          )
          .toList();

  Future<bool> _runAndReload(
    String id,
    Future<void> Function() operation,
    String notice,
  ) async {
    if (_refreshRequiredFor == id) {
      emit(
        ResourceState(
          data: state.data,
          notice:
              'Saved—refresh pending. Refresh this booking before taking another action.',
        ),
      );
      return false;
    }
    var refreshPending = false;
    final ok = await act(() async {
      await operation();
      try {
        final updated = await repository.get(id);
        if (!isClosed) {
          emit(ResourceState(data: BookingDetailsModel(updated), busy: true));
        }
      } catch (_) {
        refreshPending = true;
        _refreshRequiredFor = id;
      }
    });
    if (ok && !isClosed) {
      emit(
        ResourceState(
          data: state.data,
          notice: refreshPending
              ? 'Saved—refresh pending. Do not submit again; refresh to see the latest status.'
              : notice,
        ),
      );
    }
    return ok;
  }

  Future<bool> reportDelivery(String id) => _runAndReload(
    id,
    () => repository.transition(id, 'delivery_reported'),
    'Delivery reported. Awaiting customer confirmation. Record payment separately.',
  );
  Future<bool> recordPayment(
    String id,
    double amount, {
    double? agreedFreight,
  }) async {
    if (isClosed || state.busy || _preparingPayment) return false;
    if (!amount.isFinite || amount <= 0) {
      emit(
        ResourceState(
          data: state.data,
          error: 'Enter a valid collection amount.',
        ),
      );
      return false;
    }
    _preparingPayment = true;
    // A refresh may reveal freight set by a timed-out first payment. That must
    // not change the retry identity for the same amount collected.
    final fingerprint = '$id:$amount';
    late final String paymentKey;
    try {
      paymentKey = await paymentRequests.keyFor(fingerprint);
    } catch (_) {
      _preparingPayment = false;
      if (!isClosed) {
        emit(
          ResourceState(
            data: state.data,
            error:
                'Could not prepare a safe payment request. Please try again.',
          ),
        );
      }
      return false;
    }
    final ok = await _runAndReload(
      id,
      () => repository.recordPayment(
        id,
        amount,
        requestId: paymentKey,
        agreedFreight: agreedFreight,
      ),
      'Payment recorded and added to Finance.',
    );
    if (ok) {
      try {
        await paymentRequests.clear(fingerprint);
      } catch (_) {
        /* Safe to reuse: the backend deduplicates confirmed requests. */
      }
    }
    _preparingPayment = false;
    return ok;
  }

  Future<bool> assignTruck(String id, String vehicleId) => _runAndReload(
    id,
    () => repository.assignTruck(id, vehicleId),
    'Truck selected.',
  );
  Future<bool> markStopUnloaded(String id, int index) => _runAndReload(
    id,
    () => repository.markStopUnloaded(id, index),
    'Unloading recorded. Customer notified.',
  );
  Future<bool> reportIssue(String id, String reason) => _runAndReload(
    id,
    () => repository.reportIssue(id, reason),
    'Delivery issue reported. Please contact the driver.',
  );
  Future<bool> callContact(String phone) =>
      act(() => repository.callContact(phone));
  Future<void> load(String id) => fetch(() async {
    final booking = await repository.get(id);
    if (_refreshRequiredFor == id) _refreshRequiredFor = null;
    return BookingDetailsModel(booking);
  });
  Future<bool> transition(String id, String status, {String? reason}) =>
      _runAndReload(
        id,
        () => repository.transition(id, status, reason: reason),
        'Booking updated.',
      );

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
  Future<bool> reRequest(String loadId, {String? vehicleId}) => act(
    () => repository.request(loadId, vehicleId: vehicleId),
    notice: 'Booking request resubmitted.',
  );
}
