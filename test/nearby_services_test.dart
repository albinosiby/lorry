import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/modules/nearby_services/cubit/nearby_services_cubit.dart';
import 'package:lorry_link/modules/nearby_services/models/nearby_service_model.dart';
import 'package:lorry_link/modules/nearby_services/repositories/nearby_services_repository_interface.dart';
import 'package:lorry_link/utils/exceptions/app_exception.dart';
import 'package:lorry_link/utils/services/location_service.dart';
import 'package:lorry_link/modules/nearby_services/screens/nearby_services_screen.dart';
import 'support/fakes.dart';

class NearbyRepository implements INearbyServicesRepository {
  final requests = <Completer<List<NearbyServiceModel>>>[];
  final queries = <String?>[];
  @override
  Future<List<NearbyServiceModel>> search({
    required double latitude,
    required double longitude,
    required int radiusKm,
    NearbyServiceType? type,
    String? query,
  }) {
    queries.add(query);
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

class SectionRepository implements INearbyServicesRepository {
  bool failHospital = true;
  final radii = <NearbyServiceType?, List<int>>{};
  @override
  Future<List<NearbyServiceModel>> search({
    required double latitude,
    required double longitude,
    required int radiusKm,
    NearbyServiceType? type,
    String? query,
  }) async {
    radii.putIfAbsent(type, () => []).add(radiusKm);
    if (type == NearbyServiceType.hospital && failHospital) {
      throw const AppException('Unavailable');
    }
    if (radiusKm < 25) return [];
    return [
      for (final index in [3, 1, 2])
        NearbyServiceModel(
          id: '${type!.apiValue}-$index',
          type: type,
          name: '${type.label} $index',
          latitude: 10,
          longitude: 76,
          distanceKm: index.toDouble(),
          address: 'Nearby town',
          phone: '1234567890',
          provider: 'osm',
        ),
    ];
  }
}

void main() {
  test(
    'sections expand automatically, isolate failure and retry without losing other categories',
    () async {
      final repo = SectionRepository();
      final cubit = NearbyServicesCubit(repo, FakeLocationService());
      await cubit.discoverSections();
      expect(repo.radii[NearbyServiceType.fuel], [10, 25]);
      expect(
        cubit.state.data!.categoryErrors.keys,
        contains(NearbyServiceType.hospital),
      );
      expect(
        cubit.state.data!.services
            .where((item) => item.type == NearbyServiceType.fuel)
            .map((item) => item.distanceKm),
        [1, 2, 3],
      );
      final count = cubit.state.data!.services.length;
      repo.failHospital = false;
      await cubit.retryCategory(NearbyServiceType.hospital);
      expect(cubit.state.data!.services.length, count + 3);
      expect(cubit.state.data!.categoryErrors, isEmpty);
      expect(cubit.state.busy, isFalse);
      await cubit.close();
    },
  );
  for (final width in [320.0, 768.0, 1200.0]) {
    testWidgets('category rows and Near me fit width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = NearbyServicesCubit(
        SectionRepository()..failHospital = false,
        FakeLocationService(),
      );
      await cubit.discoverSections();
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
      expect(find.text('Near me'), findsOneWidget);
      expect(find.text('5 km'), findsNothing);
      expect(find.byKey(const ValueKey('services-fuel')), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('services-fuel')),
        const Offset(-240, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
    });
  }
  test(
    'GPS-disabled discovery shows location prompt without querying services',
    () async {
      final repo = NearbyRepository();
      final cubit = NearbyServicesCubit(repo, DisabledLocation());
      await cubit.locateAndSearch();
      expect(cubit.state.data!.location.available, isFalse);
      expect(repo.requests, isEmpty);
      expect(cubit.state.busy, isFalse);
      await cubit.close();
    },
  );
  test(
    'provider failure retains current location and filter controls data',
    () async {
      final repo = NearbyRepository();
      final cubit = NearbyServicesCubit(repo, FakeLocationService());
      final pending = cubit.locateAndSearch(type: NearbyServiceType.hotel);
      await Future<void>.delayed(Duration.zero);
      repo.requests.single.completeError(
        const AppException('Provider unavailable'),
      );
      await pending;
      expect(cubit.state.data!.location.available, isTrue);
      expect(cubit.state.data!.type, NearbyServiceType.hotel);
      expect(cubit.state.error, 'Provider unavailable');
      expect(cubit.state.busy, isFalse);
      await cubit.close();
    },
  );
  test('a slower previous search cannot replace the new search', () async {
    final repo = NearbyRepository();
    final cubit = NearbyServicesCubit(repo, FakeLocationService());
    final old = cubit.locateAndSearch(query: 'fuel');
    await Future<void>.delayed(Duration.zero);
    final next = cubit.locateAndSearch(query: 'hotel');
    await Future<void>.delayed(Duration.zero);
    repo.requests[1].complete([]);
    await next;
    repo.requests[0].complete([]);
    await old;
    expect(cubit.state.data!.query, 'hotel');
    await cubit.close();
  });
}
