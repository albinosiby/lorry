import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lorry_link/modules/account/cubit/support_cubit.dart';
import 'package:lorry_link/modules/account/models/support_request.dart';
import 'package:lorry_link/modules/account/screens/account_resources_screen.dart';
import 'package:lorry_link/modules/account/services/formspree_support_service.dart';
import 'package:lorry_link/modules/auth/cubit/session_cubit.dart';

import 'support/fakes.dart';

void main() {
  test('Formspree support request sends the expected safe payload', () async {
    late http.Request captured;
    final service = FormspreeSupportService(
      formId: 'abc123',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"next":"/thanks"}', 200);
      }),
    );

    await service.submit(
      const SupportRequest(
        name: 'Asha',
        email: 'asha@example.com',
        issue: 'Need help with a booking',
        userId: 'user-123',
        userRole: 'driver',
        phone: '+919876543210',
      ),
    );

    expect(captured.url, Uri.parse('https://formspree.io/f/abc123'));
    expect(captured.headers['content-type'], 'application/json');
    expect(jsonDecode(captured.body), {
      'name': 'Asha',
      'email': 'asha@example.com',
      'issue': 'Need help with a booking',
      'user_id': 'user-123',
      'user_role': 'driver',
      'phone': '+919876543210',
      '_subject': 'Lorry Link support request',
    });
  });

  testWidgets('support form validates and sends name, email and issue', (
    tester,
  ) async {
    final service = FormspreeSupportService(
      formId: 'abc123',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    final cubit = SupportCubit(service);
    final session = SessionCubit(FakeAuth());
    await session.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: session),
            BlocProvider.value(value: cubit),
          ],
          child: const AccountResourcesScreen(
            resource: AccountResource.support,
          ),
        ),
      ),
    );

    expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email address'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Describe the issue'),
      findsOneWidget,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Asha');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'asha@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Describe the issue'),
      'Please help with my booking.',
    );
    final submit = find.widgetWithText(FilledButton, 'Send support request');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Your support request has been sent.'), findsOneWidget);
    await cubit.close();
    await session.close();
  });
}
