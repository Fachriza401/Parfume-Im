import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parfum_im/core/network/api_client.dart';
import 'package:parfum_im/core/storage/session_store.dart';
import 'package:parfum_im/providers/auth_provider.dart';
import 'package:parfum_im/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic>? registrationBody;
  late AuthProvider authProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    registrationBody = null;

    final api = ApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/register')) {
          registrationBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'message': 'Registrasi berhasil',
              'data': <String, dynamic>{
                'token': 'registration-token',
                'user': <String, dynamic>{
                  'id': 10,
                  'name': 'Budi Santoso',
                  'email': 'budi@example.test',
                  'role': 'customer',
                },
              },
            }),
            201,
          );
        }
        return http.Response('Not found', 404);
      }),
    );
    authProvider = AuthProvider(api: api, store: await SessionStore.create());
  });

  Future<void> enterRegistrationDetails(
    WidgetTester tester, {
    String password = 'Rahasia123',
    String confirmation = 'Rahasia123',
  }) async {
    for (final entry in <(int, String)>[
      (0, 'Budi Santoso'),
      (1, 'budi@example.test'),
      (3, password),
      (4, confirmation),
    ]) {
      final field = find.byType(TextFormField).at(entry.$1);
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.$2);
    }
  }

  Future<void> pumpRegistrationScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
  }

  testWidgets('submits matching password and confirmation to the API', (
    tester,
  ) async {
    await pumpRegistrationScreen(tester);
    await enterRegistrationDetails(tester);

    final submit = find.widgetWithText(FilledButton, 'Daftar');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(registrationBody, isNotNull);
    expect(registrationBody!['password'], 'Rahasia123');
    expect(registrationBody!['password_confirmation'], 'Rahasia123');
    expect(registrationBody!.containsKey('phone'), isFalse);
    expect(authProvider.isAuthenticated, isTrue);
  });

  testWidgets('explains the backend password policy before sending', (
    tester,
  ) async {
    await pumpRegistrationScreen(tester);
    await enterRegistrationDetails(
      tester,
      password: 'password',
      confirmation: 'password',
    );

    final submit = find.widgetWithText(FilledButton, 'Daftar');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.text('Gunakan huruf besar, huruf kecil, dan angka'),
      findsOneWidget,
    );
    expect(registrationBody, isNull);
  });

  testWidgets('rejects a confirmation that does not match', (tester) async {
    await pumpRegistrationScreen(tester);
    await enterRegistrationDetails(tester, confirmation: 'Rahasia124');

    final submit = find.widgetWithText(FilledButton, 'Daftar');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Konfirmasi tidak cocok'), findsOneWidget);
    expect(registrationBody, isNull);
  });
}
