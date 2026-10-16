import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/modules/bookings/cubit/booking_details_cubit.dart';
import 'package:lorry_link/modules/tracking/models/trip_location_model.dart';
import 'package:lorry_link/utils/services/location_service.dart';
import 'support/fakes.dart';

void main() {
  test(
    'reporting delivery refreshes booking and disables live and report actions',
    () async {
      final repository = FakeBookings()..status = 'in_transit';
      final cubit = BookingDetailsCubit(repository, FakeLocationService());
      await cubit.load(repository.booking.id);
      expect(cubit.state.data!.booking.isLiveTrip, isTrue);
      expect(await cubit.reportDelivery(repository.booking.id), isTrue);
      final booking = cubit.state.data!.booking;
      expect(booking.deliveryPendingConfirmation, isTrue);
      expect(booking.canReport, isFalse);
      expect(booking.canComplete, isTrue);
      expect(booking.isLiveTrip, isFalse);
      expect(repository.collectedAmount, isNull);
      await cubit.close();
    },
  );
  test('accepted trips require collection before showing Start trip', () async {
    final repository = FakeBookings()..status = 'accepted';
    expect(repository.booking.canCollect, isTrue);
    expect(repository.booking.canStart, isFalse);
    final cubit = BookingDetailsCubit(repository, FakeLocationService());
    expect(
      await cubit.collectItems(
        repository.booking.id,
        const DeviceLocation(
          status: DeviceLocationStatus.ready,
          latitude: 10,
          longitude: 76,
        ),
      ),
      isTrue,
    );
    expect(repository.booking.status, 'accepted');
    expect(repository.booking.canCollect, isFalse);
    expect(repository.booking.canStart, isTrue);
    await cubit.close();
  });
  test(
    'GPS off preserves last point and does not imply an online location',
    () {
      final point = TripLocationModel.fromJson({
        'latitude': 10,
        'longitude': 76,
        'recorded_at': DateTime.now().toIso8601String(),
        'location_enabled': false,
      });
      expect(point.latitude, 10);
      expect(point.longitude, 76);
      expect(point.locationEnabled, isFalse);
    },
  );
}
