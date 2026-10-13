import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/app.dart';
import 'package:lorry_link/di/injection.dart';
import 'package:lorry_link/modules/home/screens/home_screen.dart';
import 'package:lorry_link/modules/auth/screens/welcome_screen.dart';
import 'support/fakes.dart';

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
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(auth.signInCalls, 1);
    expect(find.text('Hello, Anita.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    await finish(tester, auth);
  });
  testWidgets('profile requires a phone number before saving', (tester) async {
    final auth = FakeAuth();
    await start(tester, auth);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.go('/profile');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Phone number is required.'), findsOneWidget);
    await finish(tester, auth);
  });
  testWidgets(
    'post load rejects missing fields and retains form when switching tabs',
    (tester) async {
      final auth = FakeAuth();
      final loads = FakeLoads();
      await start(tester, auth, loads: loads);
      await tester.tap(find.text('Post Load'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Textile boxes');
      await tester.ensureVisible(find.text('Publish load'));
      await tester.tap(find.text('Publish load'));
      await tester.pumpAndSettle();
      expect(loads.saved, isNull);
      expect(find.text('Choose a pickup date.'), findsOneWidget);
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post Load'));
      await tester.pumpAndSettle();
      expect(find.text('Textile boxes'), findsOneWidget);
      await finish(tester, auth);
    },
  );
  testWidgets('driver filters loads and cannot open shipper route', (
    tester,
  ) async {
    final auth = FakeAuth(current: driver);
    await start(tester, auth);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.go('/loads/new');
    await tester.pumpAndSettle();
    expect(find.text('Find your next load'), findsOneWidget);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show matching loads'));
    await tester.pumpAndSettle();
    expect(find.text('Kochi'), findsOneWidget);
    await finish(tester, auth);
  });
  testWidgets('shipper accepts booking only after confirmation', (
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
  testWidgets('driver delivery and shipper completion actions follow status', (
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
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(bookings.reported, isTrue);
    expect(find.textContaining('Waiting for the shipper'), findsOneWidget);
    await finish(tester, auth);
  });
  for (final width in [320.0, 599.0, 600.0, 1199.0, 1200.0, 1440.0]) {
    testWidgets('core shipper screens fit width $width', (tester) async {
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
    for (final current in [shipper, driver]) {
      final auth = FakeAuth(current: current);
      final key = GlobalKey();
      await start(tester, auth, capture: key);
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      final role = current == shipper ? 'shipper' : 'driver';
      final routes = {
        'home': '/home',
        'loads': current == shipper ? '/loads/mine' : '/loads/find',
        if (current == shipper) 'post-load': '/loads/new',
        'load-details': '/loads/${sampleLoad.id}',
        'bookings': current == shipper ? '/requests' : '/trips',
        'booking-details': '/bookings/20000000-0000-4000-8000-000000000001',
        'notifications': '/notifications',
        'profile': '/profile',
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
