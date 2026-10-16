import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/modules/bookings/cubit/trips_cubit.dart';
import 'package:lorry_link/modules/bookings/models/booking_model.dart';
import 'support/fakes.dart';

class RequestScopeBookings extends FakeBookings {
  final scopes = <bool>[];
  @override
  Future<List<BookingModel>> list({
    bool incoming = false,
    String? loadId,
    String? status,
    int offset = 0,
  }) async {
    scopes.add(incoming);
    return offset == 0 ? List.filled(20, booking) : [];
  }
}

void main() {
  test(
    'incoming owner requests keep scope when loading more; carrier trips reset scope',
    () async {
      final repository = RequestScopeBookings();
      final cubit = TripsCubit(repository);
      await cubit.load(incoming: true, status: 'requested');
      await cubit.more();
      await cubit.load();
      expect(repository.scopes, [true, true, false]);
      await cubit.close();
    },
  );
}
