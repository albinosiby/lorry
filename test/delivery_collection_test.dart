import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/modules/bookings/cubit/booking_details_cubit.dart';
import 'support/fakes.dart';

void main() {
  test(
    'delivery collection sends the actual amount with the delivery action',
    () async {
      final repository = FakeBookings()..status = 'in_transit';
      final cubit = BookingDetailsCubit(repository, FakeLocationService());
      expect(
        await cubit.reportDeliveryWithCollection(repository.booking.id, 12500),
        isTrue,
      );
      expect(repository.reported, isTrue);
      expect(repository.collectedAmount, 12500);
      expect(cubit.state.notice, contains('Finance'));
      await cubit.close();
    },
  );
}
