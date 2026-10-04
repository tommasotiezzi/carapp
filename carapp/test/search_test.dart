import 'package:carapp/core/config/app_config.dart';
import 'package:carapp/core/storage/preferences.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/features/feed/data/feed_filters.dart';
import 'package:carapp/features/feed/data/feed_item.dart';
import 'package:carapp/features/feed/data/feed_repository.dart';
import 'package:carapp/features/feed/state/feed_filters_controller.dart';
import 'package:carapp/features/feed/ui/filter_summary.dart';
import 'package:carapp/features/onboarding/data/catalog_repository.dart';
import 'package:carapp/features/search/data/saved_search.dart';
import 'package:carapp/features/search/state/search_providers.dart';
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

const _makes = [
  Make(id: 'vw', name: 'Volkswagen', isPopular: true),
  Make(id: 'fiat', name: 'Fiat', isPopular: true),
  Make(id: 'bmw', name: 'BMW', isPopular: true),
];

FeedItem _item(String id) => FeedItem.fromRow({
      'id': id,
      'seller_type': 'private',
      'published_at': '2026-09-01T10:00:00Z',
      'year': 2019,
      'mileage_km': 50000,
      'price_cents': 990000,
      'make': {'name': 'Fiat'},
      'model': {'name': 'Panda'},
    });

class _FakeFeedRepo extends Fake implements FeedRepository {
  final requests = <FeedFilters>[];

  @override
  Future<List<FeedItem>> fetchPage({
    DateTime? before,
    int pageSize = 10,
    FeedFilters filters = FeedFilters.empty,
  }) async {
    requests.add(filters);
    return [_item('a'), _item('b'), _item('c')];
  }
}

class _FakeSearchRepo extends Fake implements SavedSearchRepository {
  _FakeSearchRepo(this.rows);

  final List<SavedSearch> rows;
  bool fail = false;

  @override
  Future<List<SavedSearch>> fetchAll() async => [...rows];

  @override
  Future<SavedSearch> create({
    required String name,
    required FeedFilters filters,
    required bool notify,
  }) async {
    if (fail) throw Exception('offline');
    return SavedSearch(id: 'new', name: name, filters: filters, notify: notify);
  }

  @override
  Future<void> delete(String id) async {
    if (fail) throw Exception('offline');
  }
}

void main() {
  final t = AppLocalizationsIt();

  test('describeFilters builds a readable name', () {
    expect(describeFilters(t, FeedFilters.empty, _makes), 'Tutti i veicoli');
    expect(
      describeFilters(
        t,
        const FeedFilters(
          categoryId: 'car',
          makeIds: {'vw', 'fiat', 'bmw'},
          priceMinCents: 500000,
          priceMaxCents: 1000000,
          yearMin: 2018,
        ),
        _makes,
      ),
      'Auto · BMW, Fiat +1 · 5–10k · Dal 2018',
    );
  });

  group('search state', () {
    late SharedPreferences prefs;
    late _FakeFeedRepo feed;
    late ProviderContainer c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      feed = _FakeFeedRepo();
      c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        feedRepositoryProvider.overrideWithValue(feed),
        currentUserIdProvider.overrideWithValue('u1'),
        savedSearchRepositoryProvider.overrideWithValue(_FakeSearchRepo([
          const SavedSearch(id: 's1', name: 'Zeta', filters: FeedFilters.empty),
        ])),
      ]);
      addTearDown(c.dispose);
    });

    test('the draft follows the feed filters until edited', () async {
      await c.read(feedFiltersProvider.notifier).apply(const FeedFilters(yearMin: 2018));
      expect(c.read(searchDraftProvider).yearMin, 2018);

      c.read(searchDraftProvider.notifier).update(const FeedFilters(yearMin: 2022));
      expect(c.read(feedFiltersProvider).yearMin, 2018, reason: 'feed untouched');
    });

    test('quick edits send one request (debounce)', () async {
      c.listen(searchResultsProvider, (_, _) {});
      final drafts = c.read(searchDraftProvider.notifier);
      drafts.update(const FeedFilters(yearMin: 2015));
      drafts.update(const FeedFilters(yearMin: 2018));
      drafts.update(const FeedFilters(yearMin: 2020));
      final state = await c.read(searchResultsProvider.future);

      expect(state.items, hasLength(3));
      expect(feed.requests, [const FeedFilters(yearMin: 2020)]);
    });

    test('saved searches: create keeps alphabetical order', () async {
      await c.read(savedSearchesProvider.future);
      await c.read(savedSearchesProvider.notifier).create(
            name: 'Alfa',
            filters: FeedFilters.empty,
            notify: true,
          );
      expect(c.read(savedSearchesProvider).value!.map((s) => s.name), ['Alfa', 'Zeta']);
    });

    test('saved searches: a failed delete rolls back', () async {
      final repo = _FakeSearchRepo([const SavedSearch(id: 's1', name: 'Zeta', filters: FeedFilters.empty)])
        ..fail = true;
      final failing = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        savedSearchRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(failing.dispose);
      await failing.read(savedSearchesProvider.future);

      await expectLater(failing.read(savedSearchesProvider.notifier).delete('s1'), throwsException);
      expect(failing.read(savedSearchesProvider).value, hasLength(1));
    });
  });

  testWidgets('Search screen on a small phone: results, saved search, Guarda nel feed', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
        GoRoute(path: '/feed', builder: (_, _) => const Text('FEED')),
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
        currentUserIdProvider.overrideWithValue('u1'),
        appConfigProvider.overrideWith((ref) async => AppConfig.empty),
        makesProvider('car').overrideWith((ref) async => _makes),
        feedRepositoryProvider.overrideWithValue(_FakeFeedRepo()),
        savedSearchRepositoryProvider.overrideWithValue(_FakeSearchRepo([
          const SavedSearch(
            id: 's1',
            name: 'Panda economica',
            filters: FeedFilters(priceMaxCents: 500000),
          ),
        ])),
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

    expect(find.text('Ricerche salvate'), findsOneWidget);
    expect(find.text('Panda economica'), findsOneWidget);
    expect(find.text('Fino a 5k'), findsWidgets); // summary + price pill

    // Pick a filter...
    await tester.dragUntilVisible(
      find.text('Dal 2022'),
      find.byType(CustomScrollView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dal 2022'));
    await tester.pumpAndSettle();

    // ...the results follow it (after the debounce)...
    await tester.pump(SearchResultsController.debounce);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Risultati'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Fiat Panda'), findsWidgets);

    // ...then watch it in the feed.
    await tester.tap(find.text('Guarda nel feed'));
    await tester.pumpAndSettle();

    expect(find.text('FEED'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.text('FEED')));
    expect(container.read(feedFiltersProvider).yearMin, 2022);
  });
}
