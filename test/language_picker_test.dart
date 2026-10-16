import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/di/injection.dart';
import 'package:lorry_link/modules/auth/screens/welcome_screen.dart';
import 'package:lorry_link/modules/home/screens/home_screen.dart';
import 'package:lorry_link/modules/settings/cubit/language_cubit.dart';
import 'package:lorry_link/modules/settings/models/app_language.dart';
import 'package:lorry_link/modules/settings/repositories/language_repository_interface.dart';
import 'package:lorry_link/modules/settings/widgets/language_picker.dart';
import 'screens_test.dart' show start, finish;
import 'support/fakes.dart';

void main() {
  test(
    'saved language survives a new Cubit; invalid codes use English',
    () async {
      final repository = FakeLanguageRepository();
      final first = LanguageCubit(repository);
      await first.load();
      expect(first.state.data, AppLanguage.english);
      for (final language in AppLanguage.values) {
        expect(await first.select(language), isTrue);
        expect(repository.code, language.code);
      }
      final restored = LanguageCubit(repository);
      await restored.load();
      expect(restored.state.data, AppLanguage.kannada);
      repository.code = 'unsupported';
      await restored.load();
      expect(restored.state.data, AppLanguage.english);
      await first.close();
      await restored.close();
    },
  );

  test('failed save keeps previous language and exposes an error', () async {
    final repository = FakeLanguageRepository()..code = 'ml';
    final cubit = LanguageCubit(repository);
    await cubit.load();
    repository.fail = true;
    expect(await cubit.select(AppLanguage.hindi), isFalse);
    expect(cubit.state.data, AppLanguage.malayalam);
    expect(cubit.state.error, isNotNull);
    await cubit.close();
  });

  testWidgets(
    'login picker switches all six locales without clearing credentials',
    (tester) async {
      final auth = FakeAuth(authenticated: false);
      await start(tester, auth);
      final router = GoRouter.of(tester.element(find.byType(WelcomeScreen)));
      router.go('/sign-in');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.invalid',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
      for (final language in AppLanguage.values) {
        await tester.ensureVisible(find.byType(LanguagePicker));
        await tester.tap(find.byType(LanguagePicker));
        await tester.pumpAndSettle();
        final choice = find.widgetWithText(ListTile, language.nativeName).last;
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(LanguagePicker));
        expect(Localizations.localeOf(context).languageCode, language.code);
        expect(find.text('test@example.invalid'), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).at(1))
              .controller
              ?.text,
          'test-password',
        );
        expect(tester.takeException(), isNull);
      }
      expect((di<ILanguageRepository>() as FakeLanguageRepository).code, 'kn');
      await finish(tester, auth);
    },
  );

  testWidgets('driver Profile Settings changes the same device preference', (
    tester,
  ) async {
    final auth = FakeAuth(current: driver);
    await start(tester, auth);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.go('/profile');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LanguagePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'മലയാളം').last);
    await tester.pumpAndSettle();
    expect(find.text('ക്രമീകരണങ്ങൾ'), findsOneWidget);
    expect(find.text('ഭാഷ'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(auth.current?.role, driver.role);
    expect(tester.takeException(), isNull);
    await finish(tester, auth);
  });
}
