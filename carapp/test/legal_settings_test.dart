import 'package:carapp/core/config/app_config.dart';
import 'package:carapp/core/storage/preferences.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/features/legal/data/consents.dart';
import 'package:carapp/features/legal/state/consent_providers.dart';
import 'package:carapp/features/legal/ui/consent_gate.dart';
import 'package:carapp/features/settings/data/account_repository.dart';
import 'package:carapp/features/settings/ui/settings_screen.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const versions = LegalVersions(terms: '2', privacy: '2');

ConsentState yes(String? v) => ConsentState(granted: true, version: v, at: DateTime(2026, 10, 1));

class _FakeConsents extends Fake implements ConsentRepository {
  _FakeConsents(this.current);

  Map<ConsentKind, ConsentState> current;
  final recorded = <bool>[];
  final changes = <(ConsentKind, bool)>[];

  @override
  Future<Map<ConsentKind, ConsentState>> fetchCurrent() async => current;

  @override
  Future<void> record(ConsentChoices choices, LegalVersions v) async {
    recorded.add(choices.marketingEmail);
    current = {
      ConsentKind.terms: yes(v.terms),
      ConsentKind.privacy: yes(v.privacy),
      ConsentKind.age14: yes(null),
      ConsentKind.marketingEmail: ConsentState(granted: choices.marketingEmail),
    };
  }

  @override
  Future<void> set(ConsentKind kind, bool granted, {String? version}) async {
    changes.add((kind, granted));
    current = {...current, kind: ConsentState(granted: granted)};
  }
}

class _FakeAccount extends Fake implements AccountRepository {
  final prefs = <String, bool>{'price_drop': false};

  @override
  Future<MyProfile> fetchProfile() async => const MyProfile(displayName: 'Mario');

  @override
  Future<Map<String, bool>> fetchNotificationPrefs() async => {...prefs};

  @override
  Future<void> setNotificationPref(String type, bool enabled) async => prefs[type] = enabled;
}

final _config = AppConfig(version: 1, values: {
  'legal': {
    'terms_url': 'https://example.com/t',
    'privacy_policy_url': 'https://example.com/p',
    'support_email': 'help@example.com',
    'terms_version': '2',
    'privacy_version': '2',
  },
});

User _user() => const User(
      id: 'u1',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-10-01T00:00:00Z',
      email: 'mario@example.com',
    );

Future<Widget> _app(Widget home, {required bool signedIn, ConsentRepository? consents, AccountRepository? account}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseProvider.overrideWithValue(SupabaseClient(
        'https://test.supabase.co',
        'anon',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      )),
      currentUserProvider.overrideWithValue(signedIn ? _user() : null),
      currentUserIdProvider.overrideWithValue(signedIn ? 'u1' : null),
      appConfigProvider.overrideWith((ref) async => _config),
      if (consents != null) consentRepositoryProvider.overrideWithValue(consents),
      if (account != null) accountRepositoryProvider.overrideWithValue(account),
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
      home: home,
    ),
  );
}

void main() {
  group('consentNeeded', () {
    final all = {
      ConsentKind.terms: yes('2'),
      ConsentKind.privacy: yes('2'),
      ConsentKind.age14: yes(null),
    };

    test('all current: nothing to ask', () => expect(consentNeeded(all, versions), isFalse));

    test('never accepted, or one required kind missing', () {
      expect(consentNeeded(const {}, versions), isTrue);
      expect(consentNeeded({...all}..remove(ConsentKind.age14), versions), isTrue);
    });

    test('a document was updated: ask again', () {
      expect(consentNeeded({...all, ConsentKind.terms: yes('1')}, versions), isTrue);
      expect(consentNeeded({...all, ConsentKind.privacy: yes('1')}, versions), isTrue);
    });

    test('promo emails never block; no versions configured = accepted once is enough', () {
      expect(
        consentNeeded({...all, ConsentKind.marketingEmail: const ConsentState(granted: false)}, versions),
        isFalse,
      );
      expect(consentNeeded({...all, ConsentKind.terms: yes('old')}, const LegalVersions()), isFalse);
    });

    test('rows sent at sign up: required granted with versions, promos as chosen', () {
      final rows = const ConsentChoices(marketingEmail: false).rows('u1', versions);
      expect(rows.map((r) => (r['kind'], r['granted'], r['document_version'])), [
        ('terms', true, '2'),
        ('privacy', true, '2'),
        ('age_14', true, null),
        ('marketing_email', false, null),
      ]);
      expect(rows.every((r) => r['profile_id'] == 'u1'), isTrue);
    });

    test('birth date: at least 14 years ago', () {
      expect(MyProfile.latestBirthDate(DateTime(2026, 10, 4)), DateTime(2012, 10, 4));
    });
  });

  group('ConsentGate', () {
    testWidgets('asks a signed-in user without consents; cannot be dismissed; accept records',
        (tester) async {
      final consents = _FakeConsents({});
      await tester.pumpWidget(await _app(
        const ConsentGate(child: Scaffold(body: Text('APP'))),
        signedIn: true,
        consents: consents,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Prima di continuare'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10)); // outside the sheet
      await tester.pumpAndSettle();
      expect(find.text('Prima di continuare'), findsOneWidget, reason: 'not dismissible');

      final accept = find.widgetWithText(FilledButton, 'Accetta e continua');
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);
      await tester.tap(find.text('Ho almeno 14 anni e accetto i Termini e condizioni'));
      await tester.tap(find.text("Ho letto l'Informativa privacy"));
      await tester.pump();
      await tester.tap(accept);
      await tester.pumpAndSettle();

      expect(consents.recorded, [false]);
      expect(find.text('Prima di continuare'), findsNothing);
    });

    testWidgets('updated documents: says so', (tester) async {
      final consents = _FakeConsents({
        ConsentKind.terms: yes('1'),
        ConsentKind.privacy: yes('1'),
        ConsentKind.age14: yes(null),
      });
      await tester.pumpWidget(await _app(
        const ConsentGate(child: Scaffold(body: Text('APP'))),
        signedIn: true,
        consents: consents,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Abbiamo aggiornato i documenti'), findsOneWidget);
    });

    testWidgets('guests and up-to-date users are never asked', (tester) async {
      await tester.pumpWidget(await _app(
        const ConsentGate(child: Scaffold(body: Text('APP'))),
        signedIn: false,
        consents: _FakeConsents({}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Prima di continuare'), findsNothing);
    });

    testWidgets('waits while the login sheet records the sign-up consents', (tester) async {
      final consents = _FakeConsents({});
      await tester.pumpWidget(await _app(
        const ConsentGate(child: Scaffold(body: Text('APP'))),
        signedIn: true,
        consents: consents,
      ));
      final container = ProviderScope.containerOf(tester.element(find.text('APP')));
      container.read(consentGateHoldProvider.notifier).set(true);
      await tester.pumpAndSettle();
      expect(find.text('Prima di continuare'), findsNothing);

      await consents.record(const ConsentChoices(marketingEmail: true), versions);
      container.invalidate(currentConsentsProvider);
      container.read(consentGateHoldProvider.notifier).set(false);
      await tester.pumpAndSettle();
      expect(find.text('Prima di continuare'), findsNothing);
    });
  });

  group('SettingsScreen', () {
    testWidgets('guest: sign-in prompt and legal documents', (tester) async {
      await tester.pumpWidget(await _app(const SettingsScreen(), signedIn: false));
      await tester.pumpAndSettle();
      expect(find.text('Accedi per gestire account, notifiche ed email.'), findsOneWidget);
      expect(find.text('Termini e condizioni'), findsOneWidget);
      expect(find.text('Elimina account'), findsNothing);
    });

    testWidgets('signed in, small phone: every section, notification and email switches',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final account = _FakeAccount();
      final consents = _FakeConsents({
        ConsentKind.terms: yes('2'),
        ConsentKind.privacy: yes('2'),
        ConsentKind.age14: yes(null),
      });
      await tester.pumpWidget(await _app(
        const SettingsScreen(),
        signedIn: true,
        consents: consents,
        account: account,
      ));
      await tester.pumpAndSettle();

      expect(find.text('mario@example.com'), findsOneWidget);
      expect(find.text('Mario'), findsOneWidget);

      // Public profile: capital and the contacts to show.
      await tester.scrollUntilVisible(find.text('Mostra il numero sul profilo'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Dove sei'), findsOneWidget);
      expect(find.text('Prima aggiungi il numero'), findsNWidgets(2));

      // Price drop is off (stored row); switch it on.
      await tester.scrollUntilVisible(find.text('Calo di prezzo dei salvati'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Calo di prezzo dei salvati'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calo di prezzo dei salvati'));
      await tester.pumpAndSettle();
      expect(account.prefs['price_drop'], isTrue);

      await tester.ensureVisible(find.text('Voglio ricevere email con novità e offerte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voglio ricevere email con novità e offerte'));
      await tester.pumpAndSettle();
      expect(consents.changes, [(ConsentKind.marketingEmail, true)]);

      await tester.scrollUntilVisible(
        find.text('Elimina account'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Accettati il 1 ott 2026'), findsOneWidget);
      expect(find.text('help@example.com'), findsOneWidget);
    });
  });
}
