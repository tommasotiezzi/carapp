import 'package:carapp/core/config/app_config.dart';
import 'package:carapp/core/storage/preferences.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/features/feed/data/feed_filters.dart';
import 'package:carapp/features/feed/data/feed_item.dart';
import 'package:carapp/features/feed/data/feed_repository.dart';
import 'package:carapp/features/feed/state/feed_controller.dart';
import 'package:carapp/features/feed/state/feed_filters_controller.dart';
import 'package:carapp/features/feed/ui/filter_summary.dart';
import 'package:carapp/features/search/data/catalog.dart';
import 'package:carapp/features/search/data/query_parser.dart';
import 'package:carapp/features/search/data/recent_searches.dart';
import 'package:carapp/features/search/data/saved_search.dart';
import 'package:carapp/features/search/data/suggestions.dart';
import 'package:carapp/features/search/ui/search_screen.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:carapp/l10n/gen/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final catalog = Catalog(
  makes: const [
    CatalogMake(id: 'vw', name: 'Volkswagen', categoryId: 'car', isPopular: true),
    CatalogMake(id: 'fiat', name: 'Fiat', categoryId: 'car', isPopular: true),
    CatalogMake(id: 'alfa', name: 'Alfa Romeo', categoryId: 'car'),
    CatalogMake(id: 'merc', name: 'Mercedes-Benz', categoryId: 'car'),
    CatalogMake(id: 'peugeot', name: 'Peugeot', categoryId: 'car'),
    CatalogMake(id: 'honda-car', name: 'Honda', categoryId: 'car'),
    CatalogMake(id: 'honda-moto', name: 'Honda', categoryId: 'motorcycle'),
  ],
  models: const [
    CatalogModel(id: 'golf', makeId: 'vw', name: 'Golf'),
    CatalogModel(id: 'polo', makeId: 'vw', name: 'Polo'),
    CatalogModel(id: 'up', makeId: 'vw', name: 'up!'),
    CatalogModel(id: 'panda', makeId: 'fiat', name: 'Panda'),
    CatalogModel(id: '500', makeId: 'fiat', name: '500'),
    CatalogModel(id: 'giulia', makeId: 'alfa', name: 'Giulia'),
    CatalogModel(id: 'classe-a', makeId: 'merc', name: 'Classe A'),
    CatalogModel(id: 'p2008', makeId: 'peugeot', name: '2008'),
    CatalogModel(id: 'civic', makeId: 'honda-car', name: 'Civic'),
    CatalogModel(id: 'cbr', makeId: 'honda-moto', name: 'CBR'),
  ],
);

final parser = QueryParser(catalog, currentYear: 2026);
FeedFilters p(String q) => parser.parse(q).filters;

FeedItem _item(String id) => FeedItem.fromRow({
      'id': id,
      'seller_type': 'private',
      'published_at': '2026-09-01T10:00:00Z',
      'year': 2019,
      'mileage_km': 50000,
      'price_cents': 1490000,
      'make': {'name': 'Volkswagen'},
      'model': {'name': 'Golf'},
    });

class _FakeFeedRepo extends Fake implements FeedRepository {
  final requests = <FeedFilters>[];

  /// Results only when there is no fuel filter (to test the zero state).
  @override
  Future<List<FeedItem>> fetchPage({
    DateTime? before,
    int pageSize = 10,
    FeedFilters filters = FeedFilters.empty,
  }) async {
    requests.add(filters);
    return filters.fuelTypes.isEmpty ? [_item('a'), _item('b')] : const [];
  }
}

class _FakeSearchRepo extends Fake implements SavedSearchRepository {
  @override
  Future<List<SavedSearch>> fetchAll() async => const [];
}

void main() {
  group('QueryParser', () {
    test('the full example', () {
      final r = parser.parse('Golf diesel dal 2018 sotto 15mila Milano');
      expect(r.filters, const FeedFilters(
        modelIds: {'golf'},
        fuelTypes: {'diesel'},
        yearMin: 2018,
        priceMaxCents: 1500000,
        province: 'MI',
      ));
      expect(r.ignored, isEmpty);
    });

    test('years: alone = that year, "dal" = from, "fino al" = up to, ranges', () {
      expect(p('panda 2015'), const FeedFilters(modelIds: {'panda'}, yearMin: 2015, yearMax: 2015));
      expect(p('dal 2018').yearMin, 2018);
      expect(p('dal 2018').yearMax, isNull);
      expect(p('fino al 2012'), const FeedFilters(yearMax: 2012));
      expect(p('dal 2010 al 2015'), const FeedFilters(yearMin: 2010, yearMax: 2015));
      expect(p('1949').yearMin, isNull, reason: 'before 1950: not a year');
      expect(p('2030').yearMin, isNull, reason: 'future: not a year');
    });

    test('prices: 8000, 8k, 8mila, sotto 10mila = max; da/tra = range', () {
      for (final q in ['8000', '8k', '8mila', '8.000', '8000 euro', '€ 8000']) {
        expect(p(q), const FeedFilters(priceMaxCents: 800000), reason: q);
      }
      expect(p('sotto 10mila'), const FeedFilters(priceMaxCents: 1000000));
      expect(p('8,5k'), const FeedFilters(priceMaxCents: 850000));
      expect(p('da 5000 a 10000'), const FeedFilters(priceMinCents: 500000, priceMaxCents: 1000000));
      expect(p('tra 5000 e 10000'), const FeedFilters(priceMinCents: 500000, priceMaxCents: 1000000));
      expect(p('oltre 20k'), const FeedFilters(priceMinCents: 2000000));
    });

    test('mileage: 100k km, 100.000 km, 100000km = max km', () {
      for (final q in ['100k km', '100.000 km', '100000km', '100mila km', '100000 chilometri']) {
        expect(p(q), const FeedFilters(mileageMaxKm: 100000), reason: q);
      }
    });

    test('category, transmission, novice, fuel synonyms', () {
      expect(
        p('auto automatica neopatentato benzina'),
        const FeedFilters(
          categoryId: 'car',
          transmission: 'automatic',
          noviceDriver: true,
          fuelTypes: {'petrol'},
        ),
      );
      expect(p('moto manuale').categoryId, 'motorcycle');
      expect(p('moto manuale').transmission, 'manual');
      expect(p('gasolio').fuelTypes, {'diesel'});
      expect(p('gpl metano').fuelTypes, {'lpg', 'cng'});
      expect(p('elettrica').fuelTypes, {'electric'});
      expect(p('ibrida').fuelTypes, {'hybrid'});
      expect(p('ibrida plug-in').fuelTypes, {'plugin_hybrid'});
      expect(p('neo patentati').noviceDriver, isTrue);
    });

    test('makes, aliases and models', () {
      expect(p('alfa giulia'), const FeedFilters(makeIds: {'alfa'}, modelIds: {'giulia'}));
      expect(p('mercedes classe a'), const FeedFilters(makeIds: {'merc'}, modelIds: {'classe-a'}));
      expect(p('vw up'), const FeedFilters(makeIds: {'vw'}, modelIds: {'up'}));
      expect(p('golf polo').modelIds, {'golf', 'polo'});
    });

    test('numbers are models only next to their make', () {
      expect(p('fiat 500'), const FeedFilters(makeIds: {'fiat'}, modelIds: {'500'}));
      expect(p('peugeot 2008'), const FeedFilters(makeIds: {'peugeot'}, modelIds: {'p2008'}));
      expect(p('2008'), const FeedFilters(yearMin: 2008, yearMax: 2008));
      expect(p('up').modelIds, isEmpty, reason: 'too short without a make');
    });

    test('a category keeps only its makes ("moto honda")', () {
      expect(p('moto honda'), const FeedFilters(categoryId: 'motorcycle', makeIds: {'honda-moto'}));
      expect(p('honda').makeIds, {'honda-car', 'honda-moto'});
    });

    test('provinces, accents included', () {
      expect(p('roma').province, 'RM');
      expect(p('reggio emilia').province, 'RE');
      expect(p("L'Aquila").province, 'AQ');
      expect(p('Forlì').province, 'FC');
    });

    test('unknown words: free text only when nothing else was understood', () {
      final withFilters = parser.parse('golf rossa');
      expect(withFilters.filters, const FeedFilters(modelIds: {'golf'}));
      expect(withFilters.ignored, ['rossa']);

      final onlyText = parser.parse('tetto panoramico');
      expect(onlyText.filters, const FeedFilters(textWords: ['tetto', 'panoramico']));
      expect(onlyText.ignored, isEmpty);

      expect(p('cerco una usata'), FeedFilters.empty, reason: 'stop words only');
    });
  });

  group('suggestions (local, every keystroke)', () {
    test('makes first, then models; a typed make narrows models', () {
      expect(suggest('volk', catalog).first.label, 'Volkswagen');
      final golf = suggest('volkswagen go', catalog).single;
      expect(golf.label, 'Volkswagen Golf');
      expect(golf.query.trim(), 'volkswagen Golf');
      expect(suggest('gol', catalog).single.query.trim(), 'Volkswagen Golf');
      expect(suggest('alfa ro', catalog).single.query.trim(), 'Alfa Romeo');
      expect(suggest('golf ', catalog), isEmpty, reason: 'word finished');
      expect(suggest('5', catalog), isEmpty);
    });
  });

  test('logicFilter: free words and novice in one safe or=()', () {
    expect(logicFilter(FeedFilters.empty), isNull);
    expect(
      logicFilter(const FeedFilters(textWords: ['tetto', 'a,b)*'])),
      'and(or(version.ilike.*tetto*,description.ilike.*tetto*),'
      'or(version.ilike.*ab*,description.ilike.*ab*))',
    );
    expect(logicFilter(const FeedFilters(noviceDriver: true)), 'and(or(category_id.neq.car,power_kw.lte.105))');
    expect(
      logicFilter(const FeedFilters(noviceDriver: true, categoryId: 'car')),
      'and(power_kw.lte.105)',
    );
  });

  test('chips: readable labels, one chip for a brand in two categories', () {
    final t = AppLocalizationsIt();
    final f = p('honda civic diesel dal 2018 sotto 8000 milano');
    expect(
      filterChips(t, f, catalog).map((c) => c.label),
      ['Honda', 'Honda Civic', 'Fino a € 8.000', 'Dal 2018', 'Diesel', 'Milano'],
    );
    final withoutHonda = filterChips(t, p('honda'), catalog).single.remove(p('honda'));
    expect(withoutHonda.makeIds, isEmpty);
    expect(describeFilters(t, FeedFilters.empty, catalog), 'Tutti i veicoli');
  });

  test('recent searches: newest first, no duplicates, max 10, on the phone', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    final recents = c.read(recentSearchesProvider.notifier);

    for (var i = 0; i < 12; i++) {
      await recents.add('ricerca $i');
    }
    await recents.add('Golf  Diesel');
    await recents.add('golf diesel');
    final list = c.read(recentSearchesProvider);
    expect(list.first, 'golf diesel');
    expect(list, hasLength(10));
    expect(list.where((q) => q.toLowerCase().contains('golf')), hasLength(1));
    expect(prefs.getStringList(PrefKeys.recentSearches), list);
  });

  group('Search screen', () {
    late _FakeFeedRepo feed;
    late SharedPreferences prefs;

    Future<ProviderContainer> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({PrefKeys.recentSearches: ['panda gpl']});
      prefs = await SharedPreferences.getInstance();
      feed = _FakeFeedRepo();

      final router = GoRouter(
        initialLocation: '/search',
        routes: [
          GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
          GoRoute(path: '/feed', builder: (_, _) => const Text('FEED')),
          GoRoute(path: '/listing/:id', builder: (_, s) => Text('LISTING ${s.pathParameters['id']}')),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          supabaseProvider.overrideWithValue(SupabaseClient(
            'https://test.supabase.co',
            'anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          )),
          currentUserIdProvider.overrideWithValue(null),
          currentUserProvider.overrideWithValue(null),
          appConfigProvider.overrideWith((ref) async => AppConfig.empty),
          catalogProvider.overrideWith((ref) async => catalog),
          feedRepositoryProvider.overrideWithValue(feed),
          savedSearchRepositoryProvider.overrideWithValue(_FakeSearchRepo()),
        ],
        child: MaterialApp.router(
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
      return ProviderScope.containerOf(tester.element(find.byType(SearchScreen)));
    }

    testWidgets('home shows recents and popular brands; typing sends nothing until the pause',
        (tester) async {
      final c = await open(tester);
      // In the app the feed list is already loaded at launch.
      c.listen(feedControllerProvider, (_, _) {});
      await c.read(feedControllerProvider.future);
      expect(find.text('Ricerche recenti'), findsOneWidget);
      expect(find.text('panda gpl'), findsOneWidget);
      expect(find.text('Marche popolari'), findsOneWidget);
      final before = feed.requests.length;

      await tester.enterText(find.byType(TextField), 'gol');
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'Volkswagen Golf'), findsOneWidget, reason: 'local suggestion');
      expect(feed.requests.length, before, reason: 'no request while typing');

      await tester.enterText(find.byType(TextField), 'golf');
      await tester.pump(const Duration(milliseconds: 200));
      expect(feed.requests.length, before, reason: 'still within the pause');
      await tester.pump(SearchScreen.typingPause);
      await tester.pumpAndSettle();
      expect(c.read(feedFiltersProvider).modelIds, {'golf'});
      expect(feed.requests.length, before + 1, reason: 'one request after the pause');
    });

    testWidgets('submit: chips, results grid, recent saved; tap opens the listing', (tester) async {
      final c = await open(tester);
      await tester.enterText(find.byType(TextField), 'golf dal 2018 rossa');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(c.read(feedFiltersProvider), const FeedFilters(modelIds: {'golf'}, yearMin: 2018));
      expect(find.widgetWithText(InputChip, 'Volkswagen Golf'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Dal 2018'), findsOneWidget);
      expect(find.text('Parole non usate: rossa'), findsOneWidget);
      expect(c.read(recentSearchesProvider).first, 'golf dal 2018 rossa');

      await tester.dragUntilVisible(
        find.text('€ 14.900').first,
        find.byType(CustomScrollView),
        const Offset(0, -150),
      );
      await tester.tap(find.text('€ 14.900').first);
      await tester.pumpAndSettle();
      expect(find.text('LISTING a'), findsOneWidget);
    });

    testWidgets('zero results: try without the last chip', (tester) async {
      final c = await open(tester);
      await tester.enterText(find.byType(TextField), 'golf diesel');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Nessun annuncio trovato'), findsOneWidget);
      expect(find.text('Salva ricerca e avvisami'), findsOneWidget);
      await tester.tap(find.text('Prova senza «Diesel»'));
      await tester.pumpAndSettle();

      expect(c.read(feedFiltersProvider), const FeedFilters(modelIds: {'golf'}));
      expect(find.text('Nessun annuncio trovato'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty,
          reason: 'the chips changed: the box no longer describes them');
    });

    testWidgets('shared state: a change from the feed pills shows up here', (tester) async {
      final c = await open(tester);
      await c.read(feedFiltersProvider.notifier).apply(const FeedFilters(fuelTypes: {'lpg'}));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'GPL'), findsOneWidget);
    });

    testWidgets('"Guarda nel feed" switches to the feed with the same filters', (tester) async {
      final c = await open(tester);
      await tester.enterText(find.byType(TextField), 'golf');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guarda nel feed'));
      await tester.pumpAndSettle();

      expect(find.text('FEED'), findsOneWidget);
      expect(c.read(feedFiltersProvider).modelIds, {'golf'});
    });
  });
}
