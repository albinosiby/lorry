import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/modules/bookings/cubit/booking_details_cubit.dart';
import 'package:lorry_link/utils/exceptions/app_exception.dart';
import 'package:lorry_link/utils/services/payment_request_store.dart';
import 'support/fakes.dart';

class UncertainPayment extends FakeBookings {
  final ids = <String>[];
  final ledger = <String>{};
  @override
  Future<void> recordPayment(
    String id,
    double amount, {
    required String requestId,
    double? agreedFreight,
  }) async {
    ids.add(requestId);
    if (ledger.add(requestId)) {
      await super.recordPayment(
        id,
        amount,
        requestId: requestId,
        agreedFreight: agreedFreight,
      );
      throw const AppException('Connection lost after save');
    }
  }
}

class RefreshFailure extends FakeBookings {
  int writes = 0;
  @override
  Future<void> transition(
    String id,
    String status, {
    String? reason,
    double? collectedAmount,
    double? latitude,
    double? longitude,
  }) async {
    writes++;
    await super.transition(
      id,
      status,
      reason: reason,
      collectedAmount: collectedAmount,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<Never> get(String id) async => throw const AppException('Offline');
}

void main() {
  test(
    'uncertain payment reuses its key after closing and reopening booking',
    () async {
      final repository = UncertainPayment()
        ..status = 'in_transit'
        ..reported = true;
      final store = MemoryPaymentRequestStore();
      final first = BookingDetailsCubit(
        repository,
        FakeLocationService(),
        paymentRequests: store,
      );
      expect(
        await first.recordPayment(
          repository.booking.id,
          2000,
          agreedFreight: 12000,
        ),
        isFalse,
      );
      await first.close();
      final reopened = BookingDetailsCubit(
        repository,
        FakeLocationService(),
        paymentRequests: store,
      );
      expect(await reopened.recordPayment(repository.booking.id, 2000), isTrue);
      expect(repository.ids[0], repository.ids[1]);
      expect(repository.totalCollected, 2000);
      expect(store.keys, isEmpty);
      expect(reopened.state.data!.booking.paymentLabel, 'Partially paid');
      await reopened.close();
    },
  );
  test(
    'a successful write with failed reload is saved, not a failed submission',
    () async {
      final repository = RefreshFailure()..status = 'in_transit';
      final cubit = BookingDetailsCubit(repository, FakeLocationService());
      expect(await cubit.reportDelivery(repository.booking.id), isTrue);
      expect(cubit.state.error, isNull);
      expect(cubit.state.notice, contains('Saved—refresh pending'));
      expect(await cubit.reportDelivery(repository.booking.id), isFalse);
      expect(repository.writes, 1);
      await cubit.close();
    },
  );
  test('stages and payment remain independent', () async {
    final repository = FakeBookings()
      ..status = 'accepted'
      ..itemsCollected = true;
    expect(repository.booking.displayStatus, 'item_collected');
    repository.status = 'in_transit';
    repository.reported = true;
    expect(repository.booking.displayStatus, 'delivery_reported');
    expect(repository.booking.canRecordPayment, isTrue);
    expect(repository.booking.isLiveTrip, isFalse);
    repository.status = 'completed';
    expect(repository.booking.displayStatus, 'delivery_confirmed');
    expect(repository.booking.canRecordPayment, isTrue);
  });
}
