import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/config/routes/routes_config.dart';
import 'package:lorry_link/modules/auth/models/auth_models.dart';
import 'package:lorry_link/modules/auth/screens/role_selection_screen.dart';
import 'package:lorry_link/modules/profile/models/profile_model.dart';

void main() {
  group('Onboarding & Role Selection Flow', () {
    testWidgets(
      'Role selection displays both options with tags and descriptions',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: RoleSelectionScreen()));

        expect(find.text('What brings you to LORRY LINK?'), findsOneWidget);
        expect(find.text('Get a truck for your load'), findsOneWidget);
        expect(find.text('Customer / Shipper'), findsOneWidget);
        expect(find.text('Get load for your truck'), findsOneWidget);
        expect(find.text('Transporter / Driver'), findsOneWidget);
        expect(find.textContaining('Sign in'), findsOneWidget);
      },
    );

    test('Profile setup criteria requires name, phone, and address', () {
      // Incomplete profile without phone or address
      const incomplete = ProfileModel(
        id: '1234',
        name: 'Anita',
        role: UserRole.shipper,
        phone: '',
        address: null,
      );
      expect(incomplete.needsSetup, isTrue);

      // Incomplete profile with phone but without address
      const withoutAddress = ProfileModel(
        id: '1234',
        name: 'Anita',
        role: UserRole.shipper,
        phone: '+919876543210',
        address: '',
      );
      expect(withoutAddress.needsSetup, isTrue);

      // Complete profile with name, phone, and address
      const completeCustomer = ProfileModel(
        id: '1234',
        name: 'Anita Logistics',
        role: UserRole.shipper,
        phone: '+919876543210',
        address: 'Kochi, Kerala',
        gender: 'Female',
      );
      expect(completeCustomer.needsSetup, isFalse);
      expect(completeCustomer.gender, 'Female');

      // Complete driver profile
      const completeDriver = ProfileModel(
        id: '5678',
        name: 'Rajesh Driver',
        role: UserRole.driver,
        phone: '+919812345678',
        address: 'Thrissur, Kerala',
        gender: 'Male',
      );
      expect(completeDriver.needsSetup, isFalse);
      expect(completeDriver.gender, 'Male');
    });

    test(
      'publicPaths allows unauthenticated access to role selection and sign up',
      () {
        const signedOut = SessionModel(SessionStatus.signedOut);

        // Welcome, role selection, sign-up and sign-in should be accessible publicly
        expect(sessionRedirect(signedOut, Uri.parse('/welcome')), isNull);
        expect(
          sessionRedirect(signedOut, Uri.parse('/role-selection')),
          isNull,
        );
        expect(sessionRedirect(signedOut, Uri.parse('/sign-up')), isNull);
        expect(sessionRedirect(signedOut, Uri.parse('/sign-in')), isNull);
        expect(sessionRedirect(signedOut, Uri.parse('/profile/terms')), isNull);

        // Private routes should redirect to sign-in
        expect(
          sessionRedirect(signedOut, Uri.parse('/home')),
          '/sign-in?from=%2Fhome',
        );
      },
    );
  });
}
