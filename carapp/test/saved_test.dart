import 'package:carapp/core/analytics/event_tracker.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/features/feed/data/feed_item.dart';
import 'package:carapp/features/saved/data/favorites_repository.dart';
import 'package:carapp/features/saved/state/saved_controller.dart';
import 'package:carapp/features/saved/ui/saved_section.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:carapp/features/onboarding/state/onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeTracker extends Fake implements EventTracker {
  final events = <AnalyticsEvent>[];

  @override
  void track(AnalyticsEvent event, {String? listingId, num? value}) => events.add(event);
}

class _FakeRepo extends Fake implements FavoritesRepository {
  _FakeRepo(this.ids);

  final Set<String> ids;
  bool fail = false;
  int fetchAllCalls = 0;

  @override
  Future<Set<String>> fetchIds() async => {...ids};

  @override
  Future<List<SavedListing>> fetchAll() async {
    fetchAllCalls++;
    return [for (final id in ids) SavedListing(listingId: id, priceCentsAtSave: 100)];
  }

  @override
  Future<void> save({required String listingId, required int? priceCents}) async {
    if (fail) throw Exception('offline');
    ids.add(listingId);
  }

  @override
  Future<void> unsave(String listingId) async {
    if (fail) throw Exception('offline');
    ids.remove(listingId);
  }
}

FeedItem _item({int? price}) => FeedItem.fromRow({
      'id': 'l1',
      'seller_type': 'private',
      'published_at': '2026-09-01T10:00:00Z',
      'year': 2019,
      'mileage_km': 78400,
      'price_cents': price,
      'make': {'name': 'Volkswagen'},
      'model': {'name': 'Golf'},
    });

void main() {
  group('SavedListing.priceDropCents', () {
    test('positive only when the price went down', () {
      expect(SavedListing(listingId: 'l1', priceCentsAtSave: 1500000, listing: _item(price: 1450000))
          .priceDropCents, 50000);
      expect(SavedListing(listingId: 'l1', priceCentsAtSave: 1500000, listing: _item(price: 1500000))
          .priceDropCents, isNull);
      expect(SavedListing(listingId: 'l1', priceCentsAtSave: 1500000, listing: _item(price: 1600000))
          .priceDropCents, isNull);
      expect(const SavedListing(listingId: 'l1', priceCentsAtSave: 1500000).priceDropCents, isNull);
    });
  });

  group('SavedController', () {
    late _FakeRepo repo;
    late _FakeTracker tracker;
    late ProviderContainer container;

    setUp(() {
      repo = _FakeRepo({'a'});
      tracker = _FakeTracker();
      container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        favoritesRepositoryProvider.overrideWithValue(repo),
        eventTrackerProvider.overrideWithValue(tracker),
      ]);
      addTearDown(container.dispose);
    });

    test('loads ids, saves and unsaves, tracks events', () async {
      expect(await container.read(savedControllerProvider.future), {'a'});
      final ctrl = container.read(savedControllerProvider.notifier);

      await ctrl.setSaved(listingId: 'b', saved: true, priceCents: 100);
      expect(container.read(isSavedProvider('b')), isTrue);
      expect(repo.ids, {'a', 'b'});

      await ctrl.setSaved(listingId: 'a', saved: false);
      expect(container.read(isSavedProvider('a')), isFalse);
      expect(tracker.events, [AnalyticsEvent.save, AnalyticsEvent.unsave]);
    });

    test('saving an already saved listing is a no-op', () async {
      await container.read(savedControllerProvider.future);
      await container.read(savedControllerProvider.notifier).setSaved(listingId: 'a', saved: true);
      expect(tracker.events, isEmpty);
    });

    test('rolls back when the write fails', () async {
      await container.read(savedControllerProvider.future);
      repo.fail = true;
      await expectLater(
        container.read(savedControllerProvider.notifier).setSaved(listingId: 'b', saved: true),
        throwsException,
      );
      expect(container.read(isSavedProvider('b')), isFalse);
      expect(tracker.events, isEmpty);
    });

    test('Salvati follows save / unsave locally, without reloading', () async {
      final salvati = await container.read(savedListingsProvider.future);
      expect(salvati.map((r) => r.listingId), ['a']);
      final ctrl = container.read(savedControllerProvider.notifier);

      await ctrl.setSaved(listingId: 'l1', saved: true, priceCents: 1450000, item: _item(price: 1450000));
      expect(container.read(savedListingsProvider).value!.map((r) => r.listingId), ['l1', 'a']);

      await ctrl.setSaved(listingId: 'a', saved: false);
      expect(container.read(savedListingsProvider).value!.map((r) => r.listingId), ['l1']);
      expect(repo.fetchAllCalls, 1, reason: 'loaded once, then updated locally');
    });

    test('guests have nothing saved', () async {
      final guest = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue(null),
        favoritesRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(guest.dispose);
      expect(await guest.read(savedControllerProvider.future), isEmpty);
    });
  });

  testWidgets('Salvati grid fits a small phone, shows drops and unavailable items', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        homeProvinceProvider.overrideWithValue(null),
        supabaseProvider.overrideWithValue(SupabaseClient(
          'https://test.supabase.co',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        )),
        savedListingsProvider.overrideWith(() => _FixedSalvati([
              SavedListing(listingId: 'l1', priceCentsAtSave: 1500000, listing: _item(price: 1450000)),
              const SavedListing(listingId: 'l2', priceCentsAtSave: 900000),
            ])),
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
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: SavedSection(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Salvati'), findsOneWidget);
    expect(find.text('€ 14.500'), findsOneWidget);
    expect(find.text('Sceso di € 500'), findsOneWidget);
    expect(find.text('Volkswagen Golf'), findsOneWidget);
    expect(find.text('Non più disponibile'), findsOneWidget);
  });
}

class _FixedSalvati extends SavedListingsController {
  _FixedSalvati(this.rows);

  final List<SavedListing> rows;

  @override
  Future<List<SavedListing>> build() async => rows;
}
