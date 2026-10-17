import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/modules/loads/screens/load_form_screen.dart';
import 'package:lorry_link/modules/bookings/models/booking_model.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/app.dart';
import 'package:lorry_link/di/injection.dart';
import 'package:lorry_link/modules/home/screens/home_screen.dart';
import 'package:lorry_link/modules/profile/screens/profile_screen.dart';
import 'package:lorry_link/modules/auth/cubit/session_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lorry_link/modules/auth/screens/welcome_screen.dart';
import 'package:lorry_link/modules/loads/models/load_model.dart';
import 'package:lorry_link/modules/verification/cubit/profile_documents_cubit.dart';
import 'package:lorry_link/modules/verification/models/profile_document_model.dart';
import 'package:lorry_link/modules/driver_documents/cubit/driver_documents_cubit.dart';
import 'package:lorry_link/modules/driver_documents/models/driver_document_model.dart';
import 'support/fakes.dart';
import 'package:lorry_link/modules/account/models/terms_content.dart';

class DriverPostedBooking extends FakeBookings {
  @override
  BookingModel get booking => BookingModel(
    id: super.booking.id,
    driverId: shipper.id,
    driverName: 'Assigned carrier',
    otherPhone: shipper.phone,
    status: 'in_transit',
    createdAt: DateTime(2026, 10, 15),
    load: LoadModel(
      id: sampleLoad.id,
      shipperId: driver.id,
      pickup: sampleLoad.pickup,
      destination: sampleLoad.destination,
      cargo: sampleLoad.cargo,
      vehicle: sampleLoad.vehicle,
      pickupDate: sampleLoad.pickupDate,
      status: 'in_transit',
      bookingId: super.booking.id,
    ),
  );
}

Future<void> start(
  WidgetTester tester,
  FakeAuth auth, {
  Size size = const Size(390, 844),
  FakeLoads? loads,
  FakeBookings? bookings,
  double scale = 1,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  await setupFakes(auth, loads: loads, bookings: bookings);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: RepaintBoundary(key: capture, child: const LorryLinkApp()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> finish(WidgetTester tester, FakeAuth auth) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  await di.reset();
  await auth.controller.close();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.platformDispatcher.clearTextScaleFactorTestValue();
}

Future<void> captureFrame(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('artifacts/previews/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  expect(tester.takeException(), isNull);
}

void main() {
  test('load models preserve intermediate unloading stops', () {
    final draft = LoadDraft(
      id: '10000000-0000-4000-8000-000000000099',
      pickup: 'Kochi',
      destination: 'Bengaluru',
      cargo: 'Mixed goods',
      vehicle: 'Open truck',
      date: DateTime(2099, 1, 1),
      pickupLatitude: 9.9312,
      pickupLongitude: 76.2673,
      destinationLatitude: 12.9716,
      destinationLongitude: 77.5946,
      unloadStops: const [
        UnloadStop(
          location: 'Thrissur',
          unloadTonnes: 1.5,
          latitude: 10.5276,
          longitude: 76.2144,
        ),
        UnloadStop(
          location: 'Coimbatore',
          latitude: 11.0168,
          longitude: 76.9558,
        ),
      ],
    );
    expect(draft.toJson()['pickup_latitude'], 9.9312);
    expect(draft.toJson()['destination_longitude'], 77.5946);
    expect(draft.toJson()['unload_stops'], [
      {
        'location': 'Thrissur',
        'unload_tonnes': 1.5,
        'latitude': 10.5276,
        'longitude': 76.2144,
      },
      {'location': 'Coimbatore', 'latitude': 11.0168, 'longitude': 76.9558},
    ]);
    final load = LoadModel.fromJson({
      'id': draft.id,
      'shipper_id': shipper.id,
      'pickup': draft.pickup,
      'destination': draft.destination,
      'cargo': draft.cargo,
      'vehicle': draft.vehicle,
      'pickup_date': '2099-01-01',
      'status': 'open',
      'unload_stops': draft.toJson()['unload_stops'],
    });
    expect(load.unloadStops, draft.unloadStops);
  });
  test('driver truck capacity filter excludes loads that do not fit', () {
    const filter = LoadFilter(
      vehicle: 'Open truck',
      maxWeightTonnes: 2,
      minVehicleLengthFt: 12,
    );
    final fittingLoad = LoadModel(
      id: '10000000-0000-4000-8000-000000000101',
      shipperId: shipper.id,
      pickup: 'Kochi',
      destination: 'Kannur',
      cargo: 'Retail cartons',
      vehicle: 'Open truck',
      pickupDate: DateTime(2099, 1, 1),
      status: 'open',
      weightTonnes: 2,
      requiredVehicleLengthFt: 12,
    );
    final tooHeavy = LoadModel(
      id: '10000000-0000-4000-8000-000000000102',
      shipperId: shipper.id,
      pickup: 'Kochi',
      destination: 'Kannur',
      cargo: 'Heavy machinery',
      vehicle: 'Open truck',
      pickupDate: DateTime(2099, 1, 1),
      status: 'open',
      weightTonnes: 2.5,
      requiredVehicleLengthFt: 12,
    );
    final tooLong = LoadModel(
      id: '10000000-0000-4000-8000-000000000103',
      shipperId: shipper.id,
      pickup: 'Kochi',
      destination: 'Kannur',
      cargo: 'Long steel sections',
      vehicle: 'Open truck',
      pickupDate: DateTime(2099, 1, 1),
      status: 'open',
      weightTonnes: 2,
      requiredVehicleLengthFt: 14,
    );

    expect(filter.matchesTruckFit(fittingLoad), isTrue);
    expect(filter.matchesTruckFit(tooHeavy), isFalse);
    expect(filter.matchesTruckFit(tooLong), isFalse);
  });
  test(
    'identity document card data changes immediately after upload or removal',
    () async {
      final repository = FakeProfileDocuments();
      final cubit = ProfileDocumentsCubit(repository);
      final draft = ProfileDocumentDraft(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'pan.jpg',
        contentType: 'image/jpeg',
        type: 'pan',
      );

      expect(await cubit.upload(draft), isTrue);
      expect(cubit.state.data, hasLength(1));
      expect(cubit.state.data!.single.type, 'pan');

      expect(await cubit.remove(cubit.state.data!.single), isTrue);
      expect(cubit.state.data, isEmpty);
      await cubit.close();
    },
  );
  test('truck document data refreshes immediately after upload', () async {
    final repository = FakeDriverDocuments();
    final cubit = DriverDocumentsCubit(repository, FakeVehicles());
    await cubit.load();

    final uploaded = await cubit.upload(
      DriverDocumentDraft(
        type: DriverDocumentType.vehicleRegistration,
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'rc.jpg',
        contentType: 'image/jpeg',
        vehicleId: '30000000-0000-4000-8000-000000000001',
      ),
    );

    expect(uploaded, isTrue);
    expect(cubit.state.data!.documents, hasLength(1));
    expect(
      cubit.state.data!.documents.single.vehicleId,
      '30000000-0000-4000-8000-000000000001',
    );
    await cubit.close();
  });
  testWidgets('sign-in validates before calling auth and reaches role home', (
    tester,
  ) async {
    final auth = FakeAuth(authenticated: false);
    await start(tester, auth);
    final router = GoRouter.of(tester.element(find.byType(WelcomeScreen)));
    router.go('/sign-in');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(auth.signInCalls, 0);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'qa@example.invalid',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secure-password');
    await tester.ensureVisible(find.text('Sign in').last);
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(auth.signInCalls, 0);
    expect(
      find.text('Please agree to the Terms & Conditions to continue.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign in').last);
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(auth.signInCalls, 1);
    expect(find.textContaining(', Anita 👋'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    await finish(tester, auth);
  });
  testWidgets(
    'sign-up requires consent and public terms preserve form values',
    (tester) async {
      final auth = FakeAuth(authenticated: false);
      await start(tester, auth);
      final router = GoRouter.of(tester.element(find.byType(WelcomeScreen)));
      router.go('/sign-up?role=driver');
      await tester.pumpAndSettle();
      for (final entry in [
        'QA Driver',
        'qa@example.invalid',
        'StrongPass123!',
        'StrongPass123!',
      ].asMap().entries) {
        await tester.enterText(
          find.byType(TextFormField).at(entry.key),
          entry.value,
        );
      }
      await tester.ensureVisible(find.text('Create account').last);
      await tester.tap(find.text('Create account').last);
      await tester.pumpAndSettle();
      expect(auth.signUpCalls, 0);
      expect(
        find.text('Please agree to the Terms & Conditions to continue.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Terms & Conditions'));
      await tester.tap(find.text('Terms & Conditions'));
      await tester.pumpAndSettle();
      for (final section in TermsContent.sections) {
        expect(find.text(section.title), findsOneWidget);
        expect(find.text(section.text), findsOneWidget);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('QA Driver'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create account').last);
      await tester.tap(find.text('Create account').last);
      await tester.pumpAndSettle();
      expect(auth.signUpCalls, 1);
      await finish(tester, auth);
    },
  );
  testWidgets(
    'Profile opens the same terms and password reset has no consent gate',
    (tester) async {
      final auth = FakeAuth();
      await start(tester, auth);
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      router.go('/profile');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Terms & Conditions'));
      await tester.tap(find.text('Terms & Conditions'));
      await tester.pumpAndSettle();
      for (final section in TermsContent.sections) {
        expect(find.text(section.text), findsOneWidget);
      }
      await finish(tester, auth);
      final signedOut = FakeAuth(authenticated: false);
      await start(tester, signedOut);
      final publicRouter = GoRouter.of(
        tester.element(find.byType(WelcomeScreen)),
      );
      publicRouter.go('/sign-in');
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 1000);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox));
      expect(tester.takeException(), isNull);
      publicRouter.go('/forgot-password');
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      await finish(tester, signedOut);
    },
  );
  testWidgets('profile requires a mobile number before saving', (tester) async {
    final auth = FakeAuth();
    await start(tester, auth);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.go('/profile');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit profile details'));
    await tester.tap(find.text('Edit profile details'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile number'),
      '',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Mobile number is required.'), findsOneWidget);
    await finish(tester, auth);
  });
  testWidgets(
    'post load rejects missing fields and retains form when switching tabs',
    (tester) async {
      final auth = FakeAuth();
      final loads = FakeLoads();
      await start(tester, auth, loads: loads);
      await tester.tap(find.text('Post Load').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Textile boxes');
      await tester.ensureVisible(find.text('Publish load to market'));
      await tester.tap(find.text('Publish load to market'));
      await tester.pumpAndSettle();
      expect(loads.saved, isNull);
      expect(find.text('Choose a pickup date.'), findsOneWidget);
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post Load').last);
      await tester.pumpAndSettle();
      expect(find.text('Textile boxes'), findsOneWidget);
      await finish(tester, auth);
    },
  );
  testWidgets('driver can post loads and still filter available freight', (
    tester,
  ) async {
    final auth = FakeAuth(current: driver);
    await start(tester, auth);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.go('/loads/new');
    await tester.pumpAndSettle();
    expect(find.byType(LoadFormScreen), findsOneWidget);
    router.go('/loads/mine');
    await tester.pumpAndSettle();
    expect(find.text('Post another load'), findsOneWidget);
    router.go('/loads/find');
    await tester.pumpAndSettle();
    expect(find.text('Available Freight Loads'), findsOneWidget);
    await tester.tap(find.text('Filter Route'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply Route Filters'));
    await tester.tap(find.text('Apply Route Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Kochi'), findsOneWidget);
    await finish(tester, auth);
  });
  testWidgets('driver Post Load is standalone and Back returns to Profile', (
    tester,
  ) async {
    final auth = FakeAuth(current: driver);
    await start(tester, auth);
    expect(
      find.widgetWithText(FilledButton, 'Post truck availability'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Post Load'));
    await tester.pumpAndSettle();
    expect(find.byType(LoadFormScreen), findsOneWidget);
    expect(find.byType(NavigationBar).hitTestable(), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(
      tester
          .element(find.byType(ProfileScreen))
          .read<SessionCubit>()
          .state
          .profile
          ?.role,
      driver.role,
    );
    await tester.ensureVisible(find.text('Post a load'));
    await tester.tap(find.text('Post a load'));
    await tester.pumpAndSettle();
    final field = find.byType(TextFormField).first;
    await tester.enterText(field, 'Unsaved pickup');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard').last);
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester, auth);
  });
  testWidgets(
    'driver posted-load Track opens carrier tracking and returns to listing',
    (tester) async {
      final auth = FakeAuth(current: driver);
      final bookings = DriverPostedBooking();
      final loads = FakeLoads()..rows = [bookings.booking.load];
      await start(tester, auth, bookings: bookings, loads: loads);
      await tester.tap(find.text('My Posted Loads').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Track'));
      await tester.tap(find.text('Track'));
      await tester.pumpAndSettle();
      expect(find.text('Call driver'), findsOneWidget);
      expect(find.text('View directions'), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Post another load'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester, auth);
    },
  );
  testWidgets(
    'driver home shows GPS status, accepted trip, and opens My Trips',
    (tester) async {
      final auth = FakeAuth(current: driver);
      final bookings = FakeBookings()
        ..status = 'accepted'
        ..itemsCollected = true;
      await start(tester, auth, bookings: bookings);
      expect(find.text('LIVE GPS ACTIVE'), findsOneWidget);
      expect(find.text('READY TO DISPATCH'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Start trip'), findsOneWidget);
      await tester.ensureVisible(find.text('My Trips').first);
      await tester.tap(find.text('My Trips').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Trips & Consignments'), findsOneWidget);
      await finish(tester, auth);
    },
  );
  testWidgets('customer accepts booking only after confirmation', (
    tester,
  ) async {
    final auth = FakeAuth();
    final bookings = FakeBookings();
    await start(tester, auth, bookings: bookings);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.push('/bookings/${bookings.booking.id}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Accept booking'));
    await tester.tap(find.text('Accept booking'));
    await tester.pumpAndSettle();
    expect(bookings.actions, isEmpty);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(bookings.actions, ['accepted']);
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Start trip'), findsNothing);
    await finish(tester, auth);
  });
  testWidgets('driver delivery and customer completion actions follow status', (
    tester,
  ) async {
    final auth = FakeAuth(current: driver);
    final bookings = FakeBookings()..status = 'in_transit';
    await start(tester, auth, bookings: bookings);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.push('/bookings/${bookings.booking.id}');
    await tester.pumpAndSettle();
    expect(find.text('Confirm delivery'), findsNothing);
    await tester.ensureVisible(find.text('Report delivery'));
    await tester.tap(find.text('Report delivery'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Confirm'),
      ),
    );
    await tester.pumpAndSettle();
    expect(bookings.reported, isTrue);
    expect(bookings.collectedAmount, isNull);
    await tester.ensureVisible(find.text('Record payment collected'));
    await tester.tap(find.text('Record payment collected'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New amount collected (₹)'),
      '5000',
    );
    await tester.tap(find.text('Record collection & add income'));
    await tester.pumpAndSettle();
    expect(bookings.collectedAmount, 5000);
    expect(find.textContaining('Waiting for the customer'), findsOneWidget);
    await finish(tester, auth);
  });
  testWidgets('driver starts a trip only with a first shared location', (
    tester,
  ) async {
    final auth = FakeAuth(current: driver);
    final bookings = FakeBookings()
      ..status = 'accepted'
      ..itemsCollected = true;
    await start(tester, auth, bookings: bookings);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.push('/bookings/${bookings.booking.id}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Start trip'));
    await tester.tap(find.widgetWithText(FilledButton, 'Start trip'));
    await tester.pumpAndSettle();
    expect(find.text('Start trip and share location?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Start trip'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(bookings.actions, contains('in_transit'));
    expect(find.text('WAITING FOR DRIVER LOCATION'), findsOneWidget);
    await finish(tester, auth);
  });
  testWidgets('driver who posted freight tracks the carrier as load owner', (
    tester,
  ) async {
    final auth = FakeAuth(current: driver);
    final bookings = DriverPostedBooking();
    await start(tester, auth, bookings: bookings);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.push('/tracking/${bookings.booking.id}');
    await tester.pumpAndSettle();
    expect(find.text('Call driver'), findsOneWidget);
    expect(find.text('View directions'), findsNothing);
    expect(tester.takeException(), isNull);
    await finish(tester, auth);
  });
  testWidgets('customer tracking waits for GPS instead of buffering forever', (
    tester,
  ) async {
    final auth = FakeAuth();
    await start(tester, auth);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.push('/tracking/20000000-0000-4000-8000-000000000001');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Waiting for the first live GPS'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.refresh_rounded), findsWidgets);
    await finish(tester, auth);
  });
  for (final width in [320.0, 599.0, 600.0, 1199.0, 1200.0, 1440.0]) {
    testWidgets('core customer screens fit width $width', (tester) async {
      final auth = FakeAuth();
      await start(tester, auth, size: Size(width, 1000));
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      expect(tester.takeException(), isNull);
      expect(
        find.byType(
          width < 600
              ? NavigationBar
              : width < 1200
              ? NavigationRail
              : NavigationDrawer,
        ),
        findsOneWidget,
      );
      for (final route in [
        '/loads/mine',
        '/loads/new',
        '/profile',
        '/notifications',
        '/loads/${sampleLoad.id}',
        '/loads/${sampleLoad.id}/edit',
        '/requests',
        '/bookings/20000000-0000-4000-8000-000000000001',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
      await finish(tester, auth);
    });
  }
  testWidgets('larger text fits small phone', (tester) async {
    final auth = FakeAuth();
    await start(tester, auth, size: const Size(390, 1000), scale: 1.8);
    expect(tester.takeException(), isNull);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.go('/profile');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await finish(tester, auth);
  });
  testWidgets('capture reviewed UI previews', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
    await tester.runAsync(() async {
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (await font.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          );
        await loader.load();
      }
    });
    await tester.runAsync(() async {
      final icons = File(
        'D:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await icons.exists()) {
        final loader = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(ByteData.sublistView(await icons.readAsBytes())),
          );
        await loader.load();
      }
    });
    for (final entry in {
      'phone': const Size(390, 844),
      'tablet': const Size(800, 1000),
      'desktop': const Size(1440, 960),
    }.entries) {
      final auth = FakeAuth();
      final key = GlobalKey();
      await start(tester, auth, size: entry.value, capture: key);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('artifacts/previews/home-${entry.key}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await finish(tester, auth);
    }
    final signedOut = FakeAuth(authenticated: false);
    final authKey = GlobalKey();
    await start(tester, signedOut, capture: authKey);
    final authRouter = GoRouter.of(tester.element(find.byType(WelcomeScreen)));
    for (final route in {
      'sign-in': '/sign-in',
      'sign-up': '/sign-up',
      'terms': '/profile/terms',
    }.entries) {
      authRouter.go(route.value);
      await tester.pumpAndSettle();
      if (route.key != 'terms') {
        await tester.ensureVisible(find.byType(Checkbox));
      }
      await tester.pumpAndSettle();
      await captureFrame(tester, authKey, 'qa-auth-${route.key}');
    }
    await finish(tester, signedOut);
    for (final current in [shipper, driver]) {
      final auth = FakeAuth(current: current);
      final key = GlobalKey();
      await start(tester, auth, capture: key);
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      final role = current == shipper ? 'shipper' : 'driver';
      final routes = {
        'home': '/home',
        'loads': current == shipper ? '/loads/mine' : '/loads/find',
        'post-load': current == shipper ? '/loads/new' : '/driver/post-load',
        if (current == driver) 'posted-loads': '/driver/posted-loads',
        'load-details': '/loads/${sampleLoad.id}',
        'bookings': current == shipper ? '/requests' : '/trips',
        'booking-details': '/bookings/20000000-0000-4000-8000-000000000001',
        'notifications': '/notifications',
        'profile': '/profile',
        'settings': '/profile/settings',
      };
      for (final route in routes.entries) {
        router.go(route.value);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));
        await captureFrame(tester, key, 'qa-$role-${route.key}');
      }
      await finish(tester, auth);
    }
  });
}
