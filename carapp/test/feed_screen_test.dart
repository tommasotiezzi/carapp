import 'dart:async';

import 'package:carapp/core/analytics/event_tracker.dart';
import 'package:carapp/core/config/app_config.dart';
import 'package:carapp/core/storage/preferences.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/features/feed/data/feed_filters.dart';
import 'package:carapp/features/feed/data/feed_item.dart';
import 'package:carapp/features/feed/data/feed_repository.dart';
import 'package:carapp/features/feed/state/feed_controller.dart';
import 'package:carapp/features/feed/state/feed_filters_controller.dart';
import 'package:carapp/features/feed/ui/feed_screen.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeTracker extends Fake implements EventTracker {
  final events = <(AnalyticsEvent, String?)>[];

  @override
  void track(AnalyticsEvent event, {String? listingId, num? value}) =>
      events.add((event, listingId));
}

/// Items without video: no player is created, the pager logic still runs.
class _FakeFeedRepo extends Fake implements FeedRepository {
  @override
  Future<List<FeedItem>> fetchPage({
    FeedItem? after,
    int pageSize = 10,
    FeedFilters filters = FeedFilters.empty,
  }) async =>
      [
        for (final id in ['a', 'b'])
          FeedItem.fromRow({
            'id': '${filters.yearMin ?? 0}-$id',
            'seller_type': 'private',
            'published_at': '2026-09-01T10:00:00Z',
            'make': {'name': 'Fiat'},
            'model': {'name': 'Panda'},
          }),
      ];
}

void main() {
  testWidgets('changing filters while the feed is open does not crash (ref in dispose)',
      (tester) async {
    SharedPreferences.setMockInitialValues({PrefKeys.onboardingDone: true});
    final prefs = await SharedPreferences.getInstance();
    final tracker = _FakeTracker();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseProvider.overrideWithValue(SupabaseClient(
          'https://test.supabase.co',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        )),
        currentUserIdProvider.overrideWithValue(null),
        appConfigProvider.overrideWith((ref) async => AppConfig.empty),
        eventTrackerProvider.overrideWithValue(tracker),
        feedRepositoryProvider.overrideWithValue(_FakeFeedRepo()),
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
        home: FeedScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tracker.events.single.$1, AnalyticsEvent.view);

    final container = ProviderScope.containerOf(tester.element(find.byType(FeedScreen)));
    await container.read(feedFiltersProvider.notifier).apply(const FeedFilters(yearMin: 2018));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The old list sent its watch time, the new list its view (Flutter
    // builds the new pager before disposing the old one).
    expect(tracker.events, hasLength(3));
    expect(tracker.events.skip(1), containsAll([
      (AnalyticsEvent.watchTime, '0-a'),
      (AnalyticsEvent.view, '2018-a'),
    ]));
  });

  group('FeedController', () {
    FeedItem item(String id, String publishedAt) => FeedItem.fromRow({
          'id': id,
          'seller_type': 'private',
          'published_at': publishedAt,
        });

    test('the page cursor uses (published_at, id): ties are not skipped', () {
      expect(
        logicFilter(FeedFilters.empty, after: item('b2', '2026-09-01T10:00:00.123456Z')),
        'and(or(published_at.lt."2026-09-01T10:00:00.123456Z",'
        'and(published_at.eq."2026-09-01T10:00:00.123456Z",id.lt.b2)))',
      );
    });

    test('a page loaded for the old filters is not appended to the new list', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _SlowRepo();
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        feedRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      repo.next = Completer()..complete(List.generate(10, (i) => item('old$i', '2026-09-01T10:00:00Z')));
      c.listen(feedControllerProvider, (_, _) {});
      final first = await c.read(feedControllerProvider.future);

      repo.next = Completer();
      final more = c.read(feedControllerProvider.notifier).loadMore();
      final stale = repo.next!;

      repo.next = Completer()..complete([item('new0', '2026-09-02T10:00:00Z')]);
      await c.read(feedFiltersProvider.notifier).apply(const FeedFilters(yearMin: 2020));
      final fresh = await c.read(feedControllerProvider.future);

      stale.complete([item('old-page-2', '2026-08-01T10:00:00Z')]);
      await more;

      final now = c.read(feedControllerProvider).value!;
      expect(now.items.map((i) => i.id), ['new0']);
      expect(now.generation, fresh.generation);
      expect(fresh.generation, isNot(first.generation));
    });

    test('refresh reloads the first page as a new list', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _SlowRepo();
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        feedRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      repo.next = Completer()..complete([item('a', '2026-09-01T10:00:00Z')]);
      c.listen(feedControllerProvider, (_, _) {});
      final first = await c.read(feedControllerProvider.future);
      repo.next = Completer()..complete([item('b', '2026-09-02T10:00:00Z')]);
      await c.read(feedControllerProvider.notifier).refresh();

      final now = c.read(feedControllerProvider).value!;
      expect(now.items.single.id, 'b');
      expect(now.generation, isNot(first.generation));
    });
  });
}

/// Answers each request with the completer set in [next].
class _SlowRepo extends Fake implements FeedRepository {
  Completer<List<FeedItem>>? next;

  @override
  Future<List<FeedItem>> fetchPage({
    FeedItem? after,
    int pageSize = 10,
    FeedFilters filters = FeedFilters.empty,
  }) =>
      next!.future;
}
