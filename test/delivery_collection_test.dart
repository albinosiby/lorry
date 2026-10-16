import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/modules/bookings/cubit/booking_details_cubit.dart';
import 'support/fakes.dart';

void main() {
  test('delivery and collection are independent actions', () async {
    final repository = FakeBookings()..status = 'in_transit';
    final cubit = BookingDetailsCubit(repository, FakeLocationService());
    expect(await cubit.reportDelivery(repository.booking.id), isTrue);
    expect(repository.reported, isTrue);
    expect(repository.collectedAmount, isNull);
    expect(await cubit.recordPayment(repository.booking.id, 12500), isTrue);
    expect(repository.collectedAmount, 12500);
    expect(cubit.state.notice, contains('Finance'));
    await cubit.close();
  });
}
