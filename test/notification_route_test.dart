import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/utils/services/notification_sync_service.dart';

void main() {
  const booking = '20000000-0000-4000-8000-000000000001';
  test('notification taps open the booking only for the intended account', () {
    final data = {'recipient_id': 'driver', 'booking_id': booking};
    expect(notificationRoute(data, 'driver'), '/bookings/$booking');
    expect(notificationRoute(data, 'customer'), isNull);
  });
  test('missing or invalid booking falls back to the notification centre', () {
    expect(
      notificationRoute({'recipient_id': 'driver'}, 'driver'),
      '/notifications',
    );
    expect(
      notificationRoute({
        'recipient_id': 'driver',
        'booking_id': '../../profile',
      }, 'driver'),
      '/notifications',
    );
  });
}
