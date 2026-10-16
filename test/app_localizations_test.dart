import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:lorry_link/l10n/catalog.dart';
import 'package:lorry_link/di/injection.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/modules/finance/repositories/finance_repository_interface.dart';
import 'package:lorry_link/modules/finance/models/finance_entry_model.dart';
import 'package:lorry_link/modules/availability/repositories/availability_repository_interface.dart';
import 'package:lorry_link/modules/availability/models/truck_availability_model.dart';
import 'package:lorry_link/modules/customer_trucks/repositories/customer_trucks_repository_interface.dart';
import 'package:lorry_link/modules/customer_trucks/models/customer_truck_model.dart';
import 'package:lorry_link/modules/driver_documents/repositories/driver_documents_repository_interface.dart';
import 'package:lorry_link/modules/nearby_services/repositories/nearby_services_repository_interface.dart';
import 'package:lorry_link/modules/account/models/terms_content.dart';
import 'package:lorry_link/modules/home/screens/home_screen.dart';
import 'package:lorry_link/modules/profile/models/profile_model.dart';
import 'package:lorry_link/modules/settings/cubit/language_cubit.dart';
import 'package:lorry_link/modules/settings/models/app_language.dart';
import 'screens_test.dart' show start, finish, captureFrame;
import 'support/fakes.dart';
import 'nearby_services_test.dart' show SectionRepository;

class LocalizedFinanceFake implements IFinanceRepository {
  @override
  Future<List<FinanceEntryModel>> list() async => [
    FinanceEntryModel(
      id: 'finance',
      type: 'income',
      category: 'freight',
      amount: 4500,
      occurredOn: DateTime.now(),
      note: 'Home',
    ),
  ];
  @override
  Future<FinanceEntryModel> save(FinanceEntryDraft draft) async =>
      FinanceEntryModel(
        id: 'new',
        type: draft.type,
        category: draft.category,
        amount: draft.amount,
        occurredOn: draft.occurredOn,
        note: draft.note,
      );
}

class LocalizedAvailabilityFake implements IAvailabilityRepository {
  @override
  Future<List<TruckAvailabilityModel>> list({bool mine = true}) async => [
    TruckAvailabilityModel(
      id: 'availability',
      driverId: driver.id,
      vehicleId: 'truck',
      currentLocation: 'Home',
      availableFrom: DateTime.now(),
      status: 'open',
      vehicle: (await FakeVehicles().list()).first,
    ),
  ];
  @override
  Future<void> close(String id) async {}
  @override
  Future<TruckAvailabilityModel> save(AvailabilityDraft draft) async =>
      (await list()).first;
}

class LocalizedTrucksFake implements ICustomerTrucksRepository {
  @override
  Future<List<CustomerTruckModel>> list({
    String query = '',
    String? loadId,
    String? vehicleType,
    double? minCapacityTonnes,
    double? latitude,
    double? longitude,
    double radiusKm = 50,
    String sort = 'nearest',
  }) async => [
    CustomerTruckModel(
      id: 'available',
      driverId: driver.id,
      location: 'Home',
      availableFrom: DateTime.now(),
      driverName: 'Home',
      vehicleType: 'Open truck',
      bodyType: 'Open truck',
      registrationLabel: '1234',
      lengthFt: 17.55,
      capacityTonnes: 4,
      distanceKm: 2.5,
    ),
  ];
  @override
  Future<void> invite({
    required String availabilityId,
    required String loadId,
  }) async {}
}

void registerExtraFakes() {
  di.registerSingleton<IFinanceRepository>(LocalizedFinanceFake());
  di.registerSingleton<IAvailabilityRepository>(LocalizedAvailabilityFake());
  di.registerSingleton<ICustomerTrucksRepository>(LocalizedTrucksFake());
  di.registerSingleton<IDriverDocumentsRepository>(FakeDriverDocuments());
  di.registerSingleton<INearbyServicesRepository>(
    SectionRepository()..failHospital = false,
  );
}

void main() {
  testWidgets('visible validation changes language without clearing input', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    final controller = TextEditingController(text: 'not-an-email');
    var code = 'en';
    late StateSetter change;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          change = setState;
          return MaterialApp(
            locale: Locale(code),
            supportedLocales: AppLanguage.values.map((l) => Locale(l.code)),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Scaffold(
              body: Form(
                key: form,
                child: AppTextField(
                  controller: controller,
                  label: 'Email address',
                  validator: Validators.email,
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    form.currentState!.validate();
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    change(() => code = 'ml');
    await tester.pumpAndSettle();
    expect(
      find.text(translateUi('Enter a valid email address.', 'ml')),
      findsOneWidget,
    );
    expect(controller.text, 'not-an-email');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  for (final width in [320.0, 800.0, 1280.0]) {
    testWidgets('localized layouts at $width with large text', (tester) async {
      final report = FlutterError.onError;
      final issues = <String>{};
      FlutterError.onError = (details) {
        final source = RegExp(
          r'\b\w+:file:[^\s]+',
        ).firstMatch(details.toString())?.group(0);
        issues.add(
          '${details.exceptionAsString()} ${source ?? details.context}',
        );
      };
      addTearDown(() => FlutterError.onError = report);
      if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
        await tester.runAsync(() async {
          for (final entry in {
            'Roboto': 'C:/Windows/Fonts/Nirmala.ttc',
            'MaterialIcons':
                'D:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          }.entries) {
            final file = File(entry.value);
            if (await file.exists()) {
              await (FontLoader(entry.key)..addFont(
                    Future.value(
                      ByteData.sublistView(await file.readAsBytes()),
                    ),
                  ))
                  .load();
            }
          }
        });
      }
      for (final role in [UserRole.shipper, UserRole.driver]) {
        final auth = FakeAuth(
          current: role == UserRole.driver ? driver : shipper,
        );
        final key = GlobalKey();
        await start(
          tester,
          auth,
          size: Size(width, 1000),
          scale: 1.3,
          capture: key,
        );
        registerExtraFakes();
        final context = tester.element(find.byType(HomeScreen));
        final router = GoRouter.of(context);
        await context.read<LanguageCubit>().select(AppLanguage.malayalam);
        await tester.pumpAndSettle();
        for (final path in [
          '/home',
          role == UserRole.driver ? '/loads/find' : '/loads/new',
          '/profile',
          '/loads/${sampleLoad.id}',
          '/bookings/${FakeBookings().booking.id}',
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$width $role $path');
          if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
            await captureFrame(
              tester,
              key,
              'localized_${role.name}_${width.toInt()}_${path.replaceAll('/', '_')}',
            );
          }
        }
        await finish(tester, auth);
      }
      FlutterError.onError = report;
      expect(issues, isEmpty, reason: issues.join('\n'));
    });
  }
  test('every catalogue entry and alias has all five translations', () {
    for (final entry in uiCatalog.entries) {
      expect(entry.value.length, 5, reason: entry.key);
      expect(
        entry.value.every((text) => text.trim().isNotEmpty),
        isTrue,
        reason: entry.key,
      );
    }
    for (final entry in uiAliases.entries) {
      expect(
        uiCatalog.containsKey(entry.value),
        isTrue,
        reason: '${entry.key} -> ${entry.value}',
      );
    }
    for (final code in ['hi', 'ml', 'ta', 'te', 'kn']) {
      for (final text in [
        'Home',
        'Post Load',
        'Find Loads',
        'My Trips',
        'Profile',
        'Driver Essentials',
        'Start trip',
        'Item collected',
        'Report delivery',
        'Vehicle RC',
        'Insurance',
        'Finance tracker',
        'This field is required.',
        'Unable to connect. Check your connection and try again.',
        'Pickup City / Place *',
        'Terms & Conditions',
      ]) {
        expect(translateUi(text, code), isNot(text), reason: '$code $text');
      }
      for (final section in TermsContent.sections) {
        expect(translateUi(section.title, code), isNot(section.title));
        expect(translateUi(section.text, code), isNot(section.text));
      }
    }
  });

  test('templates preserve names, routes, decimal feet and amounts', () {
    for (final code in ['hi', 'ml', 'ta', 'te', 'kn']) {
      expect(translateUi('Good morning, Home 👋', code), contains(', Home 👋'));
      expect(translateUi('Balance: ₹12,345.50', code), contains('₹12,345.50'));
      expect(translateUi('17.55 ft', code), contains('17.55'));
      final route = translateUi(
        'Send a booking request for Kochi to Home. The customer will review your request.',
        code,
      );
      expect(route, contains('Kochi'));
      expect(route, contains('Home'));
      expect(route, isNot(contains('{0}')));
      expect(
        translateUi('Status: In transit', code),
        isNot(contains('In transit')),
      );
      expect(
        translateUi('Custom cargo name 123', code),
        'Custom cargo name 123',
      );
    }
    expect(translateUi('Home', 'en'), 'Home');
  });

  testWidgets('const UI text responds to locale without altering raw Text', (
    tester,
  ) async {
    for (final code in ['en', 'hi', 'ml', 'ta', 'te', 'kn']) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          supportedLocales: AppLanguage.values.map((l) => Locale(l.code)),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const Scaffold(
            body: Column(children: [LocalizedText('Start trip'), Text('Home')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(translateUi('Start trip', code)), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    }
  });

  for (final role in [UserRole.driver, UserRole.shipper]) {
    testWidgets('all six languages reach $role home, forms and profile', (
      tester,
    ) async {
      final report = FlutterError.onError;
      final issues = <String>{};
      FlutterError.onError = (details) {
        final source = RegExp(
          r'(Row|Column|Wrap|Text|InputDecorator):file:[^\s]+',
        ).firstMatch(details.toString())?.group(0);
        issues.add(
          '${details.exceptionAsString()} ${source ?? details.context}',
        );
      };
      addTearDown(() => FlutterError.onError = report);
      final auth = FakeAuth(
        current: role == UserRole.driver ? driver : shipper,
      );
      await start(tester, auth);
      registerExtraFakes();
      final context = tester.element(find.byType(HomeScreen));
      final router = GoRouter.of(context);
      final language = context.read<LanguageCubit>();
      for (final locale in AppLanguage.values) {
        await language.select(locale);
        router.go('/home');
        await tester.pumpAndSettle();
        expect(find.text(translateUi('Home', locale.code)), findsWidgets);
        router.go(role == UserRole.driver ? '/loads/find' : '/loads/new');
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${locale.code} $role form',
        );
        router.go('/profile');
        await tester.pumpAndSettle();
        expect(find.text(translateUi('Settings', locale.code)), findsWidgets);
        router.go('/profile/terms');
        await tester.pumpAndSettle();
        expect(
          find.text(
            translateUi(TermsContent.sections.first.title, locale.code),
          ),
          findsOneWidget,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${locale.code} $role terms',
        );
        for (final path in [
          '/loads/${sampleLoad.id}',
          '/bookings/${FakeBookings().booking.id}',
          '/tracking/${FakeBookings().booking.id}',
          '/notifications',
          '/profile/support',
          '/profile/verification',
          '/trips',
          if (role == UserRole.driver) ...[
            '/driver/vehicles',
            '/driver/documents',
            '/driver/availability',
            '/driver/finance',
            '/driver/services',
          ],
          if (role == UserRole.shipper) '/customer/trucks',
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${locale.code} $role $path',
          );
        }
      }
      await finish(tester, auth);
      FlutterError.onError = report;
      expect(issues, isEmpty, reason: issues.join('\n'));
    });
  }
}
