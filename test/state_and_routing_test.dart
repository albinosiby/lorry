import 'package:lorry_link/modules/auth/repositories/auth_repository_interface.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/config/routes/routes_config.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/modules/auth/models/auth_models.dart';
import 'package:lorry_link/modules/auth/cubit/session_cubit.dart';
import 'package:lorry_link/modules/driver_documents/models/driver_document_model.dart';
import 'package:lorry_link/modules/loads/models/load_model.dart';
import 'package:lorry_link/modules/profile/models/profile_model.dart';
import 'package:lorry_link/utils/exceptions/app_exception.dart';
import 'support/fakes.dart';

class TestCubit extends ResourceCubit<int> {}

void main() {
  test(
    'auth guard preserves intended destination and blocks role-specific routes',
    () {
      expect(
        sessionRedirect(
          const SessionModel(SessionStatus.signedOut),
          Uri.parse('/bookings/123'),
        ),
        contains('from='),
      );
      expect(
        sessionRedirect(
          const SessionModel(SessionStatus.ready, profile: driver),
          Uri.parse('/loads/new'),
        ),
        '/loads/find',
      );
      expect(
        sessionRedirect(
          const SessionModel(SessionStatus.ready, profile: shipper),
          Uri.parse('/trips'),
        ),
        '/loads/mine',
      );
      expect(
        sessionRedirect(
          const SessionModel(SessionStatus.ready, profile: shipper),
          Uri.parse('/sign-in?from=%2Fbookings%2F123'),
        ),
        '/bookings/123',
      );
      expect(
        sessionRedirect(
          const SessionModel(SessionStatus.ready, profile: shipper),
          Uri.parse('/sign-in?from=https%3A%2F%2Fevil.invalid'),
        ),
        '/home',
      );
      expect(
        sessionRedirect(
          const SessionModel(SessionStatus.ready, profile: shipper),
          Uri.parse('/sign-in?from=%2F%2Fevil.invalid'),
        ),
        '/home',
      );
    },
  );
  test('setup, unresolved session and recovery have separate destinations', () {
    expect(
      sessionRedirect(
        const SessionModel(SessionStatus.setup),
        Uri.parse('/home'),
      ),
      '/complete-profile',
    );
    expect(
      sessionRedirect(
        const SessionModel(SessionStatus.recovery),
        Uri.parse('/home'),
      ),
      '/reset-password',
    );
    expect(
      sessionRedirect(
        const SessionModel(SessionStatus.loading),
        Uri.parse('/home'),
      ),
      startsWith('/startup'),
    );
  });
  test('ready accounts with missing required data are sent to setup', () {
    const incompleteProfile = ProfileModel(
      id: '00000000-0000-4000-8000-000000000003',
      name: 'New customer',
      role: UserRole.shipper,
      phone: '+919876543210',
    );
    const ready = SessionModel(SessionStatus.ready, profile: incompleteProfile);

    expect(sessionRedirect(ready, Uri.parse('/home')), '/complete-profile');
    expect(sessionRedirect(ready, Uri.parse('/complete-profile')), isNull);
  });
  test('Indian mobile numbers are normalized and validated', () {
    expect(ProfileModel.isValidIndianMobile('98765 43210'), isTrue);
    expect(ProfileModel.isValidIndianMobile('+91 98765 43210'), isTrue);
    expect(ProfileModel.isValidIndianMobile('1234567890'), isFalse);
    expect(ProfileModel.normalizeIndianMobile('98765 43210'), '+919876543210');
  });
  test('driver document and load-fit values use the API contract', () {
    expect(DriverDocumentType.drivingLicense.databaseValue, 'driving_license');
    expect(
      DriverDocumentType.vehicleRegistration.databaseValue,
      'vehicle_registration',
    );
    expect(
      const LoadFilter(maxWeightTonnes: 8, minVehicleLengthFt: 20).toJson(),
      containsPair('max_weight_tonnes', 8),
    );
  });
  test('later fetch wins over a stale result', () async {
    final c = TestCubit();
    final old = Completer<int>();
    final first = c.fetch(() => old.future);
    await c.fetch(() async => 2);
    old.complete(1);
    await first;
    expect(c.state.data, 2);
    await c.close();
  });
  test(
    'duplicate actions and background refresh cannot overlap mutation',
    () async {
      final c = TestCubit();
      await c.fetch(() async => 1);
      final done = Completer<void>();
      var count = 0;
      final first = c.act(() async {
        count++;
        await done.future;
      });
      expect(
        await c.act(() async {
          count++;
        }),
        isFalse,
      );
      await c.fetch(() async => 99);
      expect(c.state.busy, isTrue);
      done.complete();
      expect(await first, isTrue);
      expect(count, 1);
      expect(c.state.data, 1);
      await c.close();
    },
  );
  test(
    'repository failure maps to a usable error while preserving data',
    () async {
      final c = TestCubit();
      await c.fetch(() async => 4);
      await c.fetch(
        () async => throw const AppException('Offline. Try again.'),
      );
      expect(c.state.data, 4);
      expect(c.state.error, 'Offline. Try again.');
      await c.close();
    },
  );
  test(
    'session handles sign out, profile setup and password recovery',
    () async {
      final auth = FakeAuth();
      final c = SessionCubit(auth);
      await c.refresh();
      expect(c.state.status, SessionStatus.ready);
      auth.controller.add(SessionEvent.recovery);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.status, SessionStatus.recovery);
      await c.refresh();
      expect(c.state.status, SessionStatus.recovery);
      await c.recoveryFinished();
      expect(c.state.status, SessionStatus.ready);
      auth.current = null;
      await c.refresh();
      expect(c.state.status, SessionStatus.setup);
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.status, SessionStatus.signedOut);
      await c.close();
      await auth.controller.close();
    },
  );
}
