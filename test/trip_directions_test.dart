import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/modules/bookings/models/booking_model.dart';
import 'package:lorry_link/modules/loads/models/load_model.dart';
import 'package:lorry_link/utils/services/map_navigation_service.dart';

BookingModel trip({
  List<UnloadStop> stops = const [],
  List<int> completed = const [],
  String status = 'in_transit',
  bool collected = false,
}) => BookingModel(
  id: 'booking',
  driverId: 'driver',
  status: status,
  createdAt: DateTime(2026, 10, 15),
  itemCollectedAt: collected ? DateTime(2026, 10, 15) : null,
  unloadedStopIndices: completed,
  load: LoadModel(
    id: 'load',
    shipperId: 'owner',
    pickup: 'Kochi',
    destination: 'Kannur',
    cargo: 'Cargo',
    vehicle: 'Open truck',
    pickupDate: DateTime(2026, 10, 16),
    status: status,
    pickupLatitude: 10,
    pickupLongitude: 76,
    destinationLatitude: 12,
    destinationLongitude: 75,
    unloadStops: stops,
  ),
);

void main() {
  final service = MapNavigationService();
  const stops = [
    UnloadStop(location: 'Thrissur', latitude: 10.5, longitude: 76.2),
    UnloadStop(location: 'Kozhikode', latitude: 11.2, longitude: 75.7),
  ];

  test('before collection goes only to pickup', () {
    final plan = service.tripPlan(trip(stops: stops, status: 'accepted'));
    expect(plan.uri.queryParameters['destination'], '10.0,76.0');
    expect(plan.uri.queryParameters.containsKey('waypoints'), isFalse);
  });
  test(
    'after collection visits exact stops in posting order then destination',
    () {
      final plan = service.tripPlan(
        trip(stops: stops, status: 'accepted', collected: true),
      );
      expect(plan.uri.queryParameters['waypoints'], '10.5,76.2|11.2,75.7');
      expect(plan.uri.queryParameters['destination'], '12.0,75.0');
      expect(plan.uri.queryParameters['travelmode'], 'driving');
      expect(plan.deferredStops, 0);
    },
  );
  test(
    'completed stops are excluded using original indices, not location names',
    () {
      final plan = service.tripPlan(trip(stops: stops, completed: [0]));
      expect(plan.uri.queryParameters['waypoints'], '11.2,75.7');
      final done = service.tripPlan(trip(stops: stops, completed: [0, 1]));
      expect(done.uri.queryParameters.containsKey('waypoints'), isFalse);
      expect(done.uri.queryParameters['destination'], '12.0,75.0');
      final repeated = service.tripPlan(
        trip(stops: [stops.first, stops.first], completed: [0]),
      );
      expect(repeated.uri.queryParameters['waypoints'], '10.5,76.2');
    },
  );
  test('no intermediate stops goes straight to final destination', () {
    final plan = service.tripPlan(trip());
    expect(plan.uri.queryParameters['destination'], '12.0,75.0');
    expect(plan.uri.queryParameters.containsKey('waypoints'), isFalse);
  });
  test(
    'legacy stop names are safely URL encoded when coordinates are absent',
    () {
      final plan = service.tripPlan(
        trip(stops: const [UnloadStop(location: 'A & B, Kerala')]),
      );
      expect(plan.uri.queryParameters['waypoints'], 'A & B, Kerala');
      expect(plan.uri.toString(), contains('%26'));
    },
  );
  test(
    'ten-stop trips use sections without skipping any unloading or final delivery',
    () {
      final many = List.generate(10, (i) => UnloadStop(location: 'Stop $i'));
      final first = service.tripPlan(trip(stops: many));
      expect(first.uri.queryParameters['waypoints'], 'Stop 0|Stop 1|Stop 2');
      expect(first.uri.queryParameters['destination'], 'Stop 3');
      expect(first.deferredStops, 7);
      final second = service.tripPlan(
        trip(stops: many, completed: [0, 1, 2, 3]),
      );
      expect(second.uri.queryParameters['waypoints'], 'Stop 4|Stop 5|Stop 6');
      expect(second.uri.queryParameters['destination'], 'Stop 7');
      final last = service.tripPlan(
        trip(stops: many, completed: List.generate(8, (i) => i)),
      );
      expect(last.uri.queryParameters['waypoints'], 'Stop 8|Stop 9');
      expect(last.uri.queryParameters['destination'], '12.0,75.0');
      expect(last.deferredStops, 0);
    },
  );
}
