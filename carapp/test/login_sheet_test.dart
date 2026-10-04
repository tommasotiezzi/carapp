import 'package:carapp/core/storage/preferences.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/features/auth/data/auth_repository.dart';
import 'package:carapp/features/auth/ui/login_sheet.dart';
import 'package:carapp/features/legal/data/consents.dart';
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

class _FakeConsents extends Fake implements ConsentRepository {
  final calls = <String>[];

  @override
  Future<void> record(ConsentChoices choices, LegalVersions versions) async =>
      calls.add('record marketing=${choices.marketingEmail}');

  @override
  Future<void> keepPending(String email, ConsentChoices choices, LegalVersions versions) async =>
      calls.add('pending $email');

  @override
  Future<void> flushPending() async => calls.add('flush');
}

void main() {
  late _FakeAuth auth;
  late _FakeConsents consents;
  late SharedPreferences prefs;
  bool? result;

  setUp(() async {
    auth = _FakeAuth();
    consents = _FakeConsents();
    result = null;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        consentRepositoryProvider.overrideWithValue(consents),
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

  Future<void> acceptRequired(WidgetTester tester) async {
    await tester.tap(find.text('Ho almeno 14 anni e accetto i Termini e condizioni'));
    await tester.tap(find.text("Ho letto l'Informativa privacy"));
    await tester.pump();
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
    expect(consents.calls, ['flush'], reason: 'choices kept at sign up are recorded now');
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
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crea account')).onPressed,
      isNull,
      reason: 'Termini + age and Privacy must be ticked first',
    );
    await acceptRequired(tester);
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
    await acceptRequired(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Crea account'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signUp mario@example.com']);
    expect(consents.calls, ['pending mario@example.com'], reason: 'no session yet: kept on the phone');
    expect(find.text('Conferma la tua email'), findsOneWidget);
  });

  testWidgets('sign up records the consents (promo emails off by default)', (tester) async {
    await open(tester);
    await tester.tap(find.text('Non hai un account? Registrati'));
    await tester.pump();
    await fill(tester, 'mario@example.com', 'long-enough');
    await acceptRequired(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Crea account'));
    await tester.pumpAndSettle();

    expect(consents.calls, ['record marketing=false']);
    expect(result, isTrue);
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
