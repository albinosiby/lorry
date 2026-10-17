import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/modules/nearby_services/cubit/nearby_services_cubit.dart';
import 'package:lorry_link/modules/nearby_services/models/nearby_service_model.dart';
import 'package:lorry_link/modules/nearby_services/repositories/nearby_services_repository_interface.dart';
import 'package:lorry_link/modules/nearby_services/screens/nearby_services_screen.dart';
import 'package:lorry_link/utils/services/location_service.dart';

import 'support/fakes.dart';

class CountingRepository implements INearbyServicesRepository {
  int calls = 0;
  final requests = <({int radiusKm, NearbyServiceType? type, String? query})>[];

  @override
  Future<List<NearbyServiceModel>> search({
    required double latitude,
    required double longitude,
    required int radiusKm,
    NearbyServiceType? type,
    String? query,
  }) async {
    calls++;
    requests.add((radiusKm: radiusKm, type: type, query: query));
    return const [
      NearbyServiceModel(
        id: 'fuel-1',
        type: NearbyServiceType.fuel,
        name: 'Fuel Station',
        address: 'Nearby town',
        latitude: 10,
        longitude: 76,
        distanceKm: 1,
      ),
      NearbyServiceModel(
        id: 'hotel-1',
        type: NearbyServiceType.hotel,
        name: 'Highway Hotel',
        address: 'Town centre',
        latitude: 10,
        longitude: 76,
        distanceKm: 2,
      ),
    ];
  }
}

/// Shared with the localization screen tests. The legacy flag remains only so
/// those fixture registrations can request a fully successful response.
class SectionRepository extends CountingRepository {
  bool failHospital = false;
}

class PendingRepository implements INearbyServicesRepository {
  final requests = <Completer<List<NearbyServiceModel>>>[];

  @override
  Future<List<NearbyServiceModel>> search({
    required double latitude,
    required double longitude,
    required int radiusKm,
    NearbyServiceType? type,
    String? query,
  }) {
    final request = Completer<List<NearbyServiceModel>>();
    requests.add(request);
    return request.future;
  }
}

class DisabledLocation extends FakeLocationService {
  @override
  Future<DeviceLocation> current({bool requestPermission = true}) async =>
      const DeviceLocation(status: DeviceLocationStatus.serviceDisabled);
}

void main() {
  test('opening essentials makes one combined provider request', () async {
    final repository = CountingRepository();
    final cubit = NearbyServicesCubit(repository, FakeLocationService());

    await cubit.loadNearby();

    expect(repository.calls, 1);
    expect(repository.requests.single.radiusKm, 50);
    expect(repository.requests.single.type, isNull);
    expect(repository.requests.single.query, isNull);
    expect(cubit.state.data!.services, hasLength(2));
    await cubit.close();
  });

  test(
    'category and search filters never make another provider request',
    () async {
      final repository = CountingRepository();
      final cubit = NearbyServicesCubit(repository, FakeLocationService());
      await cubit.loadNearby();

      cubit.updateFilters(type: NearbyServiceType.fuel, query: 'station');

      expect(repository.calls, 1);
      expect(cubit.state.data!.type, NearbyServiceType.fuel);
      expect(cubit.state.data!.query, 'station');
      await cubit.close();
    },
  );

  test('Near me explicitly makes one fresh combined request', () async {
    final repository = CountingRepository();
    final cubit = NearbyServicesCubit(repository, FakeLocationService());
    await cubit.loadNearby();
    cubit.updateFilters(type: NearbyServiceType.hotel, query: 'hotel');

    await cubit.refreshNearMe();

    expect(repository.calls, 2);
    expect(repository.requests.last.type, isNull);
    expect(repository.requests.last.query, isNull);
    expect(cubit.state.data!.type, isNull);
    expect(cubit.state.data!.query, isEmpty);
    await cubit.close();
  });

  test(
    'GPS-disabled load shows a prompt without calling the provider',
    () async {
      final repository = CountingRepository();
      final cubit = NearbyServicesCubit(repository, DisabledLocation());

      await cubit.loadNearby();

      expect(cubit.state.data!.location.available, isFalse);
      expect(repository.calls, 0);
      await cubit.close();
    },
  );

  test('an older Near me request cannot replace a newer one', () async {
    final repository = PendingRepository();
    final cubit = NearbyServicesCubit(repository, FakeLocationService());
    final old = cubit.refreshNearMe();
    await Future<void>.delayed(Duration.zero);
    final next = cubit.refreshNearMe();
    await Future<void>.delayed(Duration.zero);

    repository.requests[1].complete(const []);
    await next;
    repository.requests[0].complete(const [
      NearbyServiceModel(
        id: 'old',
        type: NearbyServiceType.fuel,
        name: 'Old response',
        latitude: 10,
        longitude: 76,
      ),
    ]);
    await old;

    expect(cubit.state.data!.services, isEmpty);
    await cubit.close();
  });

  for (final width in [320.0, 768.0, 1200.0]) {
    testWidgets('filters are local and essentials fit width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = CountingRepository();
      final cubit = NearbyServicesCubit(repository, FakeLocationService());
      await cubit.loadNearby();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1800),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: BlocProvider.value(
              value: cubit,
              child: const NearbyServicesScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      cubit.updateFilters(type: NearbyServiceType.hotel);
      await tester.pump();
      expect(repository.calls, 1);
      expect(find.text('Near me'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await cubit.close();
    });
  }
}
