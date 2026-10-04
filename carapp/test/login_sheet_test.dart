import 'package:carapp/core/storage/preferences.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/features/auth/data/auth_repository.dart';
import 'package:carapp/features/auth/ui/login_sheet.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuth extends Fake implements AuthRepository {
  final calls = <String>[];
  AuthFailure? fail;
  SignUpResult signUpResult = SignUpResult.signedIn;

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn $email');
    if (fail != null) throw AuthFailureException(fail!);
  }

  @override
  Future<SignUpResult> signUp({required String email, required String password}) async {
    calls.add('signUp $email');
    if (fail != null) throw AuthFailureException(fail!);
    return signUpResult;
  }
}

void main() {
  late _FakeAuth auth;
  late SharedPreferences prefs;
  bool? result;

  setUp(() async {
    auth = _FakeAuth();
    result = null;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseProvider.overrideWithValue(SupabaseClient(
          'https://test.supabase.co',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        )),
      ],
      child: MaterialApp(
        locale: const Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showLoginSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), password);
  }

  testWidgets('signs in and closes with true', (tester) async {
    await open(tester);
    await fill(tester, ' Mario@Example.com ', 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Accedi'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signIn  Mario@Example.com ']);
    expect(result, isTrue);
  });

  testWidgets('validates email and password length before calling Supabase', (tester) async {
    await open(tester);
    await fill(tester, 'not-an-email', 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Accedi'));
    await tester.pump();
    expect(find.text("Controlla l'indirizzo email."), findsOneWidget);

    await tester.tap(find.text('Non hai un account? Registrati'));
    await tester.pump();
    await fill(tester, 'mario@example.com', 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Crea account'));
    await tester.pump();
    expect(find.text('La password deve avere almeno 8 caratteri.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('shows the Supabase error in Italian', (tester) async {
    auth.fail = AuthFailure.invalidCredentials;
    await open(tester);
    await fill(tester, 'mario@example.com', 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Accedi'));
    await tester.pumpAndSettle();

    expect(find.text('Email o password non corretti.'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('sign up with email confirmation on shows the confirm step', (tester) async {
    auth.signUpResult = SignUpResult.confirmEmail;
    await open(tester);
    await tester.tap(find.text('Non hai un account? Registrati'));
    await tester.pump();
    await fill(tester, 'mario@example.com', 'long-enough');
    await tester.tap(find.widgetWithText(FilledButton, 'Crea account'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signUp mario@example.com']);
    expect(find.text('Conferma la tua email'), findsOneWidget);
  });

  test('maps Supabase error codes', () {
    AuthFailure of(String code) =>
        AuthRepository.failureOf(AuthApiException('x', statusCode: '400', code: code));
    expect(of('invalid_credentials'), AuthFailure.invalidCredentials);
    expect(of('user_already_exists'), AuthFailure.emailTaken);
    expect(of('email_exists'), AuthFailure.emailTaken);
    expect(of('email_not_confirmed'), AuthFailure.emailNotConfirmed);
    expect(of('over_request_rate_limit'), AuthFailure.rateLimited);
    expect(of('something_new'), AuthFailure.generic);
    expect(AuthRepository.failureOf(Exception('offline')), AuthFailure.generic);
  });
}
