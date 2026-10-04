import 'dart:convert';

import 'package:carapp/core/storage/preferences.dart';
import 'package:carapp/features/feed/data/feed_filters.dart';
import 'package:carapp/features/feed/data/feed_item.dart';
import 'package:carapp/features/feed/data/feed_repository.dart';
import 'package:carapp/features/feed/state/feed_controller.dart';
import 'package:carapp/features/feed/state/feed_filters_controller.dart';
import 'package:carapp/features/feed/ui/feed_overlay.dart';
import 'package:carapp/features/feed/ui/filter_sheet.dart';
import 'package:carapp/features/onboarding/data/buyer_preferences.dart';
import 'package:carapp/features/onboarding/data/catalog_repository.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFeedRepo extends Fake implements FeedRepository {
  final requests = <FeedFilters>[];

  @override
  Future<List<FeedItem>> fetchPage({
    FeedItem? after,
    int pageSize = 10,
    FeedFilters filters = FeedFilters.empty,
  }) async {
    requests.add(filters);
    return const [];
  }
}

const _makes = [
  Make(id: 'vw', name: 'Volkswagen', isPopular: true),
  Make(id: 'fiat', name: 'Fiat', isPopular: true),
  Make(id: 'lancia', name: 'Lancia', isPopular: false),
];

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Widget _app(SharedPreferences prefs, Widget child) => ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        makesProvider('car').overrideWith((ref) async => _makes),
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
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('FeedFilters', () {
    test('starts from the onboarding preferences', () {
      final f = FeedFilters.fromPreferences(const BuyerPreferences(
        categoryId: 'car',
        budget: BudgetOption.from5to10k,
        makeIds: ['vw'],
        yearMin: 2018,
        noviceDriver: true,
      ));
      expect(f.categoryId, 'car');
      expect(f.budget, BudgetOption.from5to10k);
      expect(f.makeIds, {'vw'});
      expect(f.yearMin, 2018);
      expect(f.activeCount, 4);
    });

    test('clear() only touches its section; category also resets brands', () {
      const f = FeedFilters(categoryId: 'car', makeIds: {'vw'}, yearMin: 2018);
      expect(f.clear(FilterSection.year), const FeedFilters(categoryId: 'car', makeIds: {'vw'}));
      expect(f.clear(FilterSection.vehicle), const FeedFilters(yearMin: 2018));
    });

    test('JSON round trip and set equality', () {
      const f = FeedFilters(priceMaxCents: 500000, fuelTypes: {'diesel', 'lpg'}, makeIds: {'a', 'b'});
      expect(FeedFilters.fromJson(jsonDecode(jsonEncode(f.toJson()))), f);
      expect(const FeedFilters(makeIds: {'a', 'b'}), const FeedFilters(makeIds: {'b', 'a'}));
      expect(FeedFilters.empty.isEmpty, isTrue);
    });
  });

  group('FeedFiltersController', () {
    test('follows preferences until the user applies filters, then persists them', () async {
      final prefs = await _prefs({
        PrefKeys.buyerPreferences: jsonEncode(const BuyerPreferences(yearMin: 2015).toJson()),
      });
      final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);

      expect(c.read(feedFiltersProvider).yearMin, 2015);

      await c.read(feedFiltersProvider.notifier).apply(const FeedFilters(mileageMaxKm: 50000));
      expect(c.read(feedFiltersProvider), const FeedFilters(mileageMaxKm: 50000));

      // A new launch reads the user's filters, not the preferences.
      final next = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(next.dispose);
      expect(next.read(feedFiltersProvider), const FeedFilters(mileageMaxKm: 50000));
    });

    test('the feed reloads with the new filters, and only when they change', () async {
      final prefs = await _prefs();
      final repo = _FakeFeedRepo();
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        feedRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      c.listen(feedControllerProvider, (_, _) {});

      await c.read(feedControllerProvider.future);
      await c.read(feedFiltersProvider.notifier).apply(const FeedFilters(yearMin: 2020));
      await c.read(feedControllerProvider.future);
      await c.read(feedFiltersProvider.notifier).apply(const FeedFilters(yearMin: 2020));
      await c.read(feedControllerProvider.future);

      expect(repo.requests, [FeedFilters.empty, const FeedFilters(yearMin: 2020)]);
    });
  });

  group('FilterSheet', () {
    testWidgets('a pill section applies on "Mostra annunci"', (tester) async {
      final prefs = await _prefs();
      await tester.pumpWidget(_app(prefs, const FilterSheet(only: FilterSection.price)));
      await tester.tap(find.text('5–10k'));
      await tester.pump();

      final container = ProviderScope.containerOf(tester.element(find.byType(FilterSheet)));
      expect(container.read(feedFiltersProvider).isEmpty, isTrue, reason: 'draft only');

      await tester.tap(find.text('Mostra annunci'));
      await tester.pump();
      expect(container.read(feedFiltersProvider).budget, BudgetOption.from5to10k);
    });

    testWidgets('full sheet fits a small phone; "+ Altre" shows every brand', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prefs = await _prefs();

      await tester.pumpWidget(_app(prefs, const FilterSheet()));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('+ Altre'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      expect(find.text('Lancia'), findsNothing);
      await tester.tap(find.text('+ Altre'));
      await tester.pump();
      expect(find.text('Lancia'), findsOneWidget);
    });
  });

  testWidgets('pills show the active values and the count', (tester) async {
    final prefs = await _prefs({
      PrefKeys.feedFilters: jsonEncode(const FeedFilters(
        priceMinCents: 500000,
        priceMaxCents: 1000000,
        makeIds: {'vw'},
        fuelTypes: {'diesel'},
      ).toJson()),
    });
    final item = FeedItem.fromRow({
      'id': 'l1',
      'seller_type': 'private',
      'published_at': '2026-09-01T10:00:00Z',
    });

    await tester.pumpWidget(_app(
      prefs,
      FeedOverlay(
        item: item,
        saved: false,
        onOpenDetail: () {},
        onSave: () {},
        onShare: () {},
        onContact: () {},
        onOpenFilters: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('5–10k'), findsOneWidget);
    expect(find.text('Volkswagen'), findsOneWidget);
    expect(find.text('Anno'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // price + brand + fuel
  });
}
