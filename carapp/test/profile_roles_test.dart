import 'package:carapp/core/config/app_config.dart';
import 'package:carapp/core/storage/preferences.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/core/theme/app_theme.dart';
import 'package:carapp/features/listing/data/listing_detail.dart';
import 'package:carapp/features/listing/state/listing_providers.dart';
import 'package:carapp/features/listing/ui/listing_screen.dart';
import 'package:carapp/features/my_listings/data/my_listings_repository.dart';
import 'package:carapp/features/my_listings/ui/edit_listing_screen.dart';
import 'package:carapp/features/onboarding/data/catalog_repository.dart';
import 'package:carapp/features/onboarding/state/onboarding_controller.dart';
import 'package:carapp/features/profile/ui/profile_screen.dart';
import 'package:carapp/features/saved/data/favorites_repository.dart';
import 'package:carapp/features/search/data/catalog.dart';
import 'package:carapp/features/sell/data/sell_draft.dart';
import 'package:carapp/features/sell/data/sell_repository.dart';
import 'package:carapp/features/saved/state/saved_controller.dart';
import 'package:carapp/features/settings/data/account_repository.dart';
import 'package:carapp/features/settings/state/settings_providers.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sell_test.dart' show FakeSellRepository;

const _me = 'me';

class FakeMyListingsRepository implements MyListingsRepository {
  FakeMyListingsRepository(this.rows);

  List<MyListing> rows;
  final statuses = <(String, String)>[];
  final prices = <(String, int)>[];
  final offers = <(String, int)>[];
  OfferFailure? failOffer;

  @override
  Future<List<MyListing>> fetch() async => rows;

  @override
  Future<void> setStatus(String listingId, String status) async => statuses.add((listingId, status));

  @override
  Future<void> updatePrice(String listingId, int priceCents) async => prices.add((listingId, priceCents));

  ({String categoryId, String status, SellDetails details})? editable;
  final updated = <(String, SellDetails)>[];

  @override
  Future<({String categoryId, String status, SellDetails details})?> fetchForEdit(String listingId) async => editable;

  @override
  Future<void> updateDetails(String listingId, SellDetails details) async => updated.add((listingId, details));

  @override
  Future<int> offerToSavers(String listingId, int priceCents) async {
    if (failOffer != null) throw OfferException(failOffer!);
    offers.add((listingId, priceCents));
    return rows.firstWhere((l) => l.id == listingId).saves;
  }
}

class _Profile extends MyProfileController {
  _Profile(this.value);

  final MyProfile? value;

  @override
  Future<MyProfile?> build() async => value;
}

class _Dealer extends MyDealerController {
  _Dealer(this.value);

  final MyDealer? value;

  @override
  Future<MyDealer?> build() async => value;
}

class _NoSaved extends SavedListingsController {
  @override
  Future<List<SavedListing>> build() async => const [];
}

const _golf = MyListing(
  id: 'l1',
  status: 'active',
  categoryId: 'car',
  title: 'Volkswagen Golf',
  year: 2019,
  priceCents: 1490000,
  saves: 12,
  chats: 3,
);

const _panda = MyListing(
  id: 'l2',
  status: 'sold',
  categoryId: 'car',
  title: 'Fiat Panda',
  priceCents: 500000,
);

void main() {
  late SharedPreferences prefs;
  late FakeMyListingsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = FakeMyListingsRepository([_golf, _panda]);
  });

  test('MyListing: the offer waits 24 h after the last one', () {
    final now = DateTime(2026, 10, 4, 12);
    expect(_golf.canOffer(now), isTrue);
    final sent = _golf.copyWith(lastOfferAt: DateTime(2026, 10, 4, 10), lastOfferPriceCents: 1400000);
    expect(sent.canOffer(now), isFalse);
    expect(sent.nextOfferAt(now), DateTime(2026, 10, 5, 10));
    expect(sent.canOffer(DateTime(2026, 10, 5, 10, 1)), isTrue);
    expect(_panda.canOffer(now), isFalse, reason: 'sold');
    expect(_golf.copyWith(status: 'active').canOffer(now), isTrue);
    expect(const MyListing(id: 'x', status: 'active', categoryId: 'car', priceCents: 1).canOffer(now), isFalse,
        reason: 'nobody saved it');
  });

  test('OfferException maps the database errors', () {
    OfferFailure of(String m) => OfferException.from(PostgrestException(message: m)).failure;
    expect(of('offer_too_soon'), OfferFailure.tooSoon);
    expect(of('offer_not_lower'), OfferFailure.notLower);
    expect(of('offer_too_low'), OfferFailure.tooLow);
    expect(of('no_savers'), OfferFailure.noSavers);
    expect(of('listing_unavailable'), OfferFailure.unavailable);
    expect(OfferException.from(Exception('x')).failure, OfferFailure.other);
  });

  group('profile', () {
    Widget app({
      String? intent,
      String? savedIntent,
      MyDealer? dealer,
      bool signedIn = true,
      List<Override> more = const [],
    }) {
      if (intent != null) prefs.setString(PrefKeys.userIntent, intent);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
        GoRoute(path: '/sell', builder: (_, _) => const Text('sell')),
        GoRoute(path: '/onboarding/dealer', builder: (_, _) => const Text('dealer signup')),
        GoRoute(path: '/dealers/:id', builder: (_, s) => Text('dealer page ${s.pathParameters['id']}')),
        GoRoute(path: '/listing/:id', builder: (_, s) => Text('listing ${s.pathParameters['id']}')),
        GoRoute(path: '/settings', builder: (_, _) => const Text('settings')),
      ]);
      return KeyedSubtree(
        key: UniqueKey(),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            supabaseProvider.overrideWithValue(SupabaseClient(
              'https://test.supabase.co',
              'anon',
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            )),
            homeProvinceProvider.overrideWithValue(null),
            currentUserIdProvider.overrideWithValue(signedIn ? _me : null),
            currentUserProvider.overrideWithValue(signedIn
                ? User(id: _me, appMetadata: const {}, userMetadata: const {}, aud: 'a', createdAt: '2026', email: 'me@x.it')
                : null),
            appConfigProvider.overrideWith((ref) async => AppConfig.empty),
            myProfileProvider.overrideWith(() => _Profile(signedIn ? MyProfile(displayName: 'Giulia', intent: savedIntent) : null)),
            myDealerProvider.overrideWith(() => _Dealer(dealer)),
            savedListingsProvider.overrideWith(_NoSaved.new),
            myListingsRepositoryProvider.overrideWithValue(repo),
            ...more,
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            locale: const Locale('it'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      );
    }

    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(430, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('explorer: a neutral profile that asks what you need; the choice reshapes it', (tester) async {
      tall(tester);
      repo.rows = [];
      await tester.pumpWidget(app(intent: 'browse'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('needs-card')), findsOneWidget);
      expect(find.text('Semplifica la tua esperienza scegliendo quello di cui hai bisogno'), findsOneWidget);
      expect(find.text('Cosa cerco'), findsNothing);
      expect(find.text('Giulia'), findsOneWidget);
      expect(find.text('Salvati'), findsOneWidget);

      await tester.tap(find.text('Voglio vendere'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('needs-card')), findsNothing);
      expect(find.text('Stai vendendo'), findsOneWidget);
      expect(find.byKey(const ValueKey('my-listings')), findsOneWidget);
      expect(prefs.getString(PrefKeys.userIntent), 'sell');

      // "Cambia" goes back to neutral.
      await tester.tap(find.byKey(const ValueKey('change-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sto solo guardando'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('needs-card')), findsOneWidget);
    });

    testWidgets('no choice on this phone: the one saved on the account', (tester) async {
      tall(tester);
      await tester.pumpWidget(app(savedIntent: 'buy'));
      await tester.pumpAndSettle();
      expect(find.text('Cosa cerco'), findsOneWidget);
      expect(find.text('Stai cercando un veicolo'), findsOneWidget);
      // A buyer who also sells still sees their listings.
      expect(find.text('I miei annunci'), findsOneWidget);
    });

    testWidgets('dealer pending: the VAT check', (tester) async {
      tall(tester);
      await tester.pumpWidget(app(intent: 'dealer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verifica la partita IVA'));
      await tester.pumpAndSettle();
      expect(find.text('dealer signup'), findsOneWidget);
    });

    testWidgets('explorer choosing "concessionario" opens the VAT check', (tester) async {
      tall(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sono un concessionario'));
      await tester.pumpAndSettle();
      expect(find.text('dealer signup'), findsOneWidget);
    });

    testWidgets('dealer: totals, page, listings; no role switch', (tester) async {
      tall(tester);
      await tester.pumpWidget(app(
        intent: 'buy',
        dealer: const MyDealer(id: 'd1', isOwner: true, displayName: 'Auto Bianchi'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Auto Bianchi'), findsOneWidget);
      expect(find.byKey(const ValueKey('dealer-card')), findsOneWidget);
      expect(find.text('12'), findsOneWidget); // saves on active listings
      expect(find.byKey(const ValueKey('change-role')), findsNothing);
      expect(find.text('Cosa cerco'), findsNothing);
      expect(find.text('Salvati'), findsNothing);
      await tester.tap(find.text('Vedi la pagina del concessionario'));
      await tester.pumpAndSettle();
      expect(find.text('dealer page d1'), findsOneWidget);
    });

    testWidgets('seller: statuses, counts, actions by status, offer to savers', (tester) async {
      tall(tester);
      await tester.pumpWidget(app(intent: 'sell'));
      await tester.pumpAndSettle();

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Venduto'), findsOneWidget);
      expect(find.text("12 persone l'hanno salvato"), findsOneWidget);
      expect(find.text('3 chat'), findsOneWidget);

      // Sold: only "Rimetti in vendita".
      await tester.tap(find.byTooltip('Azioni').last);
      await tester.pumpAndSettle();
      expect(find.text('Rimetti in vendita'), findsOneWidget);
      expect(find.text('Segna come venduto'), findsNothing);
      await tester.tap(find.text('Rimetti in vendita'));
      await tester.pumpAndSettle();
      expect(repo.statuses.single, ('l2', 'active'));
      expect(find.text('Venduto'), findsNothing);

      // The offer: 5% off suggested, validation, then sent.
      await tester.tap(find.text("Offerta a chi l'ha salvato"));
      await tester.pumpAndSettle();
      expect(find.textContaining('12 persone'), findsWidgets);
      expect(find.text('14.150'), findsOneWidget); // 14.900 − 5%, down to 50 €
      await tester.enterText(find.byType(TextField), '15000');
      await tester.tap(find.text('Invia a 12 persone'));
      await tester.pumpAndSettle();
      expect(find.text('Deve essere più basso del prezzo attuale'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '5000');
      await tester.tap(find.text('Invia a 12 persone'));
      await tester.pumpAndSettle();
      expect(find.text('Non più della metà di sconto'), findsOneWidget);
      await tester.tap(find.text('−10%'));
      await tester.pump();
      await tester.tap(find.text('Invia a 12 persone'));
      await tester.pumpAndSettle();
      expect(repo.offers.single, ('l1', 1340000));
      expect(find.text('Offerta inviata a 12 persone'), findsOneWidget);
      expect(find.textContaining('Offerta inviata: € 13.400'), findsOneWidget);
      expect(find.text("Offerta a chi l'ha salvato"), findsNothing);
    });

    testWidgets('offer refused by the database: the reason shows in the sheet', (tester) async {
      tall(tester);
      repo.failOffer = OfferFailure.tooSoon;
      await tester.pumpWidget(app(intent: 'sell'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Offerta a chi l'ha salvato"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invia a 12 persone'));
      await tester.pumpAndSettle();
      expect(find.text("Puoi fare un'offerta ogni 24 ore"), findsOneWidget);
    });

    testWidgets('remove asks first; price change', (tester) async {
      tall(tester);
      await tester.pumpWidget(app(intent: 'sell'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Azioni').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambia prezzo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '13900');
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      expect(repo.prices.single, ('l1', 1390000));
      expect(find.text('€ 13.900'), findsOneWidget);

      await tester.tap(find.byTooltip('Azioni').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rimuovi annuncio'));
      await tester.pumpAndSettle();
      expect(find.text("Rimuovere l'annuncio?"), findsOneWidget);
      await tester.tap(find.text('Rimuovi annuncio').last);
      await tester.pumpAndSettle();
      expect(repo.statuses.single, ('l1', 'removed'));
      expect(find.text('Volkswagen Golf · 2019'), findsNothing);
    });
  });

  testWidgets('edit: the sell form filled with the listing, saved with one update', (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo.editable = (
      categoryId: 'car',
      status: 'active',
      details: SellDetails.fromJson({
        'make_id': 'vw',
        'model_id': 'golf',
        'year': 2019,
        'mileage_km': 78400,
        'price_cents': 1490000,
        'fuel_type': 'diesel',
        'city': 'Milano',
        'province': 'MI',
        'whatsapp_enabled': false,
        'attributes': {'novice_ok': true},
      }),
    );
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('profile'))),
      GoRoute(path: '/edit', builder: (_, _) => const EditListingScreen(listingId: 'l1')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseProvider.overrideWithValue(SupabaseClient(
          'https://test.supabase.co',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        )),
        homeProvinceProvider.overrideWithValue('SI'),
        currentUserIdProvider.overrideWithValue(_me),
        appConfigProvider.overrideWith((ref) async => AppConfig.empty),
        myListingsRepositoryProvider.overrideWithValue(repo),
        sellRepositoryProvider.overrideWithValue(FakeSellRepository()),
        catalogProvider.overrideWith((ref) async => Catalog(
              makes: const [CatalogMake(id: 'vw', name: 'Volkswagen', categoryId: 'car')],
              models: const [CatalogModel(id: 'golf', makeId: 'vw', name: 'Golf')],
            )),
        makesProvider('car').overrideWith((ref) async => const [Make(id: 'vw', name: 'Volkswagen', categoryId: 'car')]),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        locale: const Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ));
    await tester.pumpAndSettle();
    router.push('/edit');
    await tester.pumpAndSettle();

    expect(find.text('Modifica annuncio'), findsOneWidget);
    expect(find.textContaining('Video e foto restano'), findsOneWidget);
    expect(find.text('Volkswagen'), findsOneWidget);
    expect(find.text('Golf'), findsOneWidget);
    expect(find.text('78.400'), findsOneWidget);
    expect(find.text('14.900'), findsOneWidget);
    expect(find.text('Milano'), findsOneWidget, reason: 'not replaced by the home capital');
    expect(find.textContaining('Stiamo preparando'), findsNothing);
    expect(find.textContaining('Ho almeno 18 anni'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Chilometri'), '81000');
    await tester.enterText(find.byType(TextField).at(2), '13900');
    await tester.tap(find.text('Salva modifiche'));
    await tester.pumpAndSettle();

    final (id, saved) = repo.updated.single;
    expect(id, 'l1');
    final row = saved.toListingRow();
    expect(row['mileage_km'], 81000);
    expect(row['price_cents'], 1390000);
    expect(row['province'], 'MI');
    expect(row['attributes'], {'novice_ok': true});
    expect(find.text('profile'), findsOneWidget);
    expect(find.text('Modifiche salvate'), findsOneWidget);
  });

  testWidgets('edit: a listing that is not the user\'s', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        myListingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: EditListingScreen(listingId: 'x'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Questo annuncio non si può modificare.'), findsOneWidget);
  });

  testWidgets('own listing page: the offer to the savers in the bar', (tester) async {
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseProvider.overrideWithValue(SupabaseClient(
        'https://test.supabase.co',
        'anon',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      )),
      homeProvinceProvider.overrideWithValue(null),
      currentUserIdProvider.overrideWithValue(_me),
      currentUserProvider.overrideWithValue(null),
      appConfigProvider.overrideWith((ref) async => AppConfig.empty),
      myListingsRepositoryProvider.overrideWithValue(repo),
      savedControllerProvider.overrideWith(() => _NoSavedIds()),
      listingDetailProvider('l1').overrideWith((ref) async => ListingDetail.fromRow({
            'id': 'l1',
            'seller_type': 'private',
            'owner_id': _me,
            'category_id': 'car',
            'price_cents': 1490000,
            'make': {'name': 'Volkswagen'},
            'model': {'name': 'Golf'},
          })),
      listingQuestionsProvider('l1').overrideWith((ref) async => const []),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ListingScreen(id: 'l1'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text("Offerta a chi l'ha salvato (12)"), findsOneWidget);
    expect(find.byTooltip('Modifica annuncio'), findsOneWidget);
    await tester.tap(find.text("Offerta a chi l'ha salvato (12)"));
    await tester.pumpAndSettle();
    expect(find.text('Prezzo riservato'), findsOneWidget);
  });
}

class _NoSavedIds extends SavedController {
  @override
  Future<Set<String>> build() async => const {};
}
