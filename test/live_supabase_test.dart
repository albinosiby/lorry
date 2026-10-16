import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:lorry_link/utils/services/supabase_service.dart';
import 'package:lorry_link/utils/exceptions/app_exception.dart';
import 'package:lorry_link/modules/auth/repositories/auth_repository.dart';
import 'package:lorry_link/modules/auth/models/auth_models.dart';
import 'package:lorry_link/modules/profile/repositories/profile_repository.dart';
import 'package:lorry_link/modules/profile/models/profile_model.dart';
import 'package:lorry_link/modules/loads/models/load_model.dart';
import 'package:lorry_link/modules/loads/repositories/load_repository.dart';
import 'package:lorry_link/modules/bookings/repositories/booking_repository.dart';
import 'package:lorry_link/modules/notifications/repositories/notification_repository.dart';
import 'package:lorry_link/modules/home/repositories/home_repository.dart';
import 'package:lorry_link/modules/vehicles/repositories/vehicle_repository.dart';
import 'package:lorry_link/modules/vehicles/models/vehicle_model.dart';

void main() {
  test(
    'Hosted Supabase: auth, competing acceptance, private data, delivery and notifications',
    () async {
      final config = jsonDecode(
        File('config/supabase.local.json').readAsStringSync(),
      );
      final accounts =
          jsonDecode(File('config/smoke.local.json').readAsStringSync())
              as List;
      final clients = List.generate(
        3,
        (_) => SupabaseClient(
          config['SUPABASE_URL'],
          config['SUPABASE_PUBLISHABLE_KEY'],
        ),
      );
      final services = clients.map(SupabaseService.new).toList();
      final truckIds = <String>[];
      try {
        for (var i = 0; i < 3; i++) {
          final auth = AuthRepository(services[i]);
          await auth.signIn(
            SignInModel(accounts[i]['email'], accounts[i]['password']),
          );
          expect(auth.signedIn, isTrue);
          await ProfileRepository(services[i]).save(
            name: 'QA ${i == 0 ? 'Shipper' : 'Driver $i'}',
            phone: '+91987654321$i',
            role: i == 0 ? UserRole.shipper : UserRole.driver,
          );
          expect(
            (await auth.profile())?.role,
            i == 0 ? UserRole.shipper : UserRole.driver,
          );
          if (i > 0) {
            final fleet = VehicleRepository(services[i]);
            final existing = await fleet.list();
            final qa = existing
                .where((v) => v.registrationNumber == 'QA 01 AB 1234')
                .firstOrNull;
            final truck = await fleet.save(
              VehicleDraft(
                id: qa?.id,
                registrationNumber: 'QA 01 AB 1234',
                vehicleType: 'Open truck',
                bodyType: 'Open truck',
                lengthFt: 20,
                capacityTonnes: 10,
              ),
            );
            truckIds.add(truck.id);
          }
        }
        final loads = LoadRepository(services[0]);
        final driverLoads = LoadRepository(services[1]);
        final bookingOwner = BookingRepository(services[0]),
            driverBookings = BookingRepository(services[1]),
            otherBookings = BookingRepository(services[2]);
        final draft = LoadDraft(
          id: const Uuid().v4(),
          pickup: 'Kochi',
          destination: 'Bengaluru',
          cargo: 'Automated QA shipment - remove after test',
          vehicle: 'Open truck',
          date: DateTime.now().add(const Duration(days: 7)),
          price: 12000,
          pickupLatitude: 10,
          pickupLongitude: 76,
          destinationLatitude: 12,
          destinationLongitude: 77,
        );
        final load = await loads.save(draft);
        expect((await loads.save(draft)).id, load.id);
        expect(
          (await driverLoads.list(
            filter: const LoadFilter(pickup: 'Kochi'),
          )).any((l) => l.id == load.id),
          isTrue,
        );
        final first = await driverBookings.request(
              load.id,
              vehicleId: truckIds[0],
            ),
            second = await otherBookings.request(
              load.id,
              vehicleId: truckIds[1],
            );
        expect(
          await driverBookings.request(load.id, vehicleId: truckIds[0]),
          first,
        );
        await expectLater(
          otherBookings.get(first),
          throwsA(isA<AppException>()),
        );
        // Two concurrent owner acceptance requests: exactly one must win.
        final outcomes = await Future.wait(
          [first, second].map((id) async {
            try {
              await bookingOwner.transition(id, 'accepted');
              return id;
            } on AppException {
              return null;
            }
          }),
        );
        expect(outcomes.whereType<String>().length, 1);
        final winner = outcomes.whereType<String>().single;
        final winningDriver = winner == first ? driverBookings : otherBookings;
        final winnerService = winner == first ? services[1] : services[2];
        final accepted = await winningDriver.get(winner);
        expect(accepted.status, 'accepted');
        expect(accepted.otherPhone, isNotEmpty);
        final loser = await bookingOwner.get(winner == first ? second : first);
        expect(loser.status, 'declined');
        await expectLater(
          winningDriver.transition(winner, 'completed'),
          throwsA(isA<AppException>()),
        );
        await winningDriver.transition(
          winner,
          'item_collected',
          latitude: 10,
          longitude: 76,
        );
        await winningDriver.transition(
          winner,
          'in_transit',
          latitude: 10,
          longitude: 76,
        );
        await winningDriver.transition(winner, 'delivery_reported');
        await winningDriver.recordPayment(
          winner,
          12000,
          requestId: const Uuid().v4(),
        );
        await bookingOwner.transition(winner, 'completed');
        final completed = await winningDriver.get(winner);
        expect(completed.status, 'completed');
        expect(completed.load.status, 'completed');
        expect(completed.events.length, 7);
        expect(
          (await HomeRepository(services[0]).get()).completed,
          greaterThanOrEqualTo(1),
        );
        final notices = NotificationRepository(winnerService);
        expect(await notices.list(), isNotEmpty);
        await notices.markRead();
        expect((await notices.list()).every((n) => n.readAt != null), isTrue);
        await expectLater(
          clients[1].from('loads').update({'status': 'open'}).eq('id', load.id),
          throwsA(isA<PostgrestException>()),
        );
        for (final service in services) {
          await AuthRepository(service).signOut();
        }
      } finally {
        for (final client in clients) {
          await client.dispose();
        }
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
