import 'package:carapp/core/config/app_config.dart';
import 'package:carapp/core/geo/distance_label.dart';
import 'package:carapp/core/geo/italian_capitals.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/features/feed/data/feed_filters.dart';
import 'package:carapp/features/feed/data/feed_item.dart';
import 'package:carapp/features/feed/data/feed_repository.dart';
import 'package:carapp/features/feed/ui/filter_summary.dart';
import 'package:carapp/features/listing/data/listing_detail.dart';
import 'package:carapp/features/listing/state/listing_providers.dart';
import 'package:carapp/features/onboarding/data/buyer_preferences.dart';
import 'package:carapp/features/onboarding/state/onboarding_controller.dart';
import 'package:carapp/features/search/data/catalog.dart';
import 'package:carapp/features/search/data/query_parser.dart';
import 'package:carapp/features/seller/data/seller_repository.dart';
import 'package:carapp/features/seller/ui/seller_screen.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _catalog = Catalog(
  makes: const [CatalogMake(id: 'vw', name: 'Volkswagen', categoryId: 'car')],
  models: const [CatalogModel(id: 'golf', makeId: 'vw', name: 'Golf')],
);

class _FakeSellers implements SellerRepository {
  _FakeSellers(this.profile);

  final SellerProfile? profile;

  @override
  Future<SellerProfile?> fetch(SellerRef ref) async => profile;

  @override
  Future<int> activeCount(SellerRef ref) async => 2;
}

class _FakeFeed implements FeedRepository {
  final calls = <(FeedFilters, SellerRef?)>[];

  @override
  Future<List<FeedItem>> fetchPage({
    FeedItem? after,
    int pageSize = 10,
    FeedFilters filters = FeedFilters.empty,
    SellerRef? seller,
  }) async {
    calls.add((filters, seller));
    final all = [
      FeedItem(
        id: 'l1',
        sellerType: 'dealer',
        publishedAt: DateTime(2026, 10),
        makeName: 'Volkswagen',
        modelName: 'Golf',
        priceCents: 1490000,
        city: 'Firenze',
        province: 'FI',
        dealerId: 'd1',
      ),
      FeedItem(
        id: 'l2',
        sellerType: 'dealer',
        publishedAt: DateTime(2026, 9),
        makeName: 'Ducati',
        modelName: 'Monster',
        priceCents: 790000,
        city: 'Firenze',
        province: 'FI',
        dealerId: 'd1',
      ),
    ];
    return filters.categoryId == 'motorcycle' ? [all[1]] : all;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  group('capitals', () {
    test('106 capitals, real distances', () {
      expect(ItalianCapitals.all, hasLength(106));
      expect(ItalianCapitals.byCode['SI']!.name, 'Siena');
      expect(ItalianCapitals.distanceKm('SI', 'FI')!, closeTo(51, 2));
      expect(ItalianCapitals.distanceKm('SI', 'MI')!, closeTo(293, 3));
      expect(ItalianCapitals.distanceKm('MI', 'MB')!, closeTo(15, 2));
      expect(ItalianCapitals.distanceKm('SI', 'XX'), isNull);
    });

    test('Siena + 100 km: Florence yes, Milan no', () {
      final near = ItalianCapitals.within('SI', 100);
      expect(near, containsAll(['SI', 'FI', 'AR', 'GR', 'PI', 'PG']));
      expect(near, isNot(contains('MI')));
      expect(near, isNot(contains('RM')));
      expect(ItalianCapitals.within('XX', 100), isEmpty);
    });

    test('nearest capital to a point', () {
      expect(ItalianCapitals.nearestTo(43.32, 11.33).code, 'SI'); // Siena centre
      expect(ItalianCapitals.nearestTo(45.47, 9.19).code, 'MI');
    });
  });

  group('distance filter', () {
    test('provinces in range, crossed with a province', () {
      const f = FeedFilters(nearProvince: 'SI', radiusKm: 100);
      expect(f.hasDistance, isTrue);
      expect(f.provincesInRange, contains('FI'));
      expect(f.copyWith(province: 'FI').provincesInRange, {'FI'});
      expect(f.copyWith(province: 'MI').provincesInRange, isEmpty);
      expect(FeedFilters.empty.provincesInRange, isNull);
      expect(f.activeCount, 1);
      expect(f.clear(FilterSection.distance).hasDistance, isFalse);
    });

    test('json, equality, from the onboarding preferences', () {
      const f = FeedFilters(nearProvince: 'SI', radiusKm: 50, categoryId: 'car');
      expect(FeedFilters.fromJson(f.toJson()), f);
      expect(f == const FeedFilters(nearProvince: 'SI', radiusKm: 100, categoryId: 'car'), isFalse);

      final fromPrefs = FeedFilters.fromPreferences(const BuyerPreferences(province: 'SI', maxDistanceKm: 50));
      expect((fromPrefs.nearProvince, fromPrefs.radiusKm), ('SI', 50));
      // "Tutta Italia" = no distance filter, the capital still kept for distances.
      final allItaly = FeedFilters.fromPreferences(const BuyerPreferences(province: 'SI'));
      expect(allItaly.hasDistance, isFalse);
      expect(BuyerPreferences.fromJson(const BuyerPreferences(province: 'SI', maxDistanceKm: 50).toJson()).province, 'SI');
    });

    testWidgets('labels: chip and "km da te"', (tester) async {
      late AppLocalizations t;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(builder: (context) {
          t = AppLocalizations.of(context);
          return const SizedBox();
        }),
      ));
      expect(distanceLabelOf(t, const FeedFilters(nearProvince: 'SI', radiusKm: 50)), 'Entro 50 km da Siena');
      expect(filterChips(t, const FeedFilters(nearProvince: 'SI', radiusKm: 50), null).first.label,
          'Entro 50 km da Siena');
      expect(distanceLabel(t, home: 'SI', province: 'FI'), '50 km da te');
      expect(distanceLabel(t, home: 'MI', province: 'MB'), '15 km da te');
      expect(distanceLabel(t, home: 'SI', province: 'SI'), 'Nella tua provincia');
      expect(distanceLabel(t, home: null, province: 'SI'), isNull);
    });
  });

  group('search', () {
    final home = QueryParser(_catalog, currentYear: 2026, homeProvince: 'SI');
    final guest = QueryParser(_catalog, currentYear: 2026);

    test('"vicino a me" around the user\'s capital, default 50 km', () {
      final f = home.parse('golf vicino a me').filters;
      expect((f.nearProvince, f.radiusKm), ('SI', 50));
      expect(f.modelIds, {'golf'});
    });

    test('"entro 100 km da firenze": the city is the center', () {
      final f = home.parse('golf entro 100 km da firenze').filters;
      expect((f.nearProvince, f.radiusKm), ('FI', 100));
      expect(f.province, isNull);
      expect(f.mileageMaxKm, isNull);
    });

    test('mileage stays mileage', () {
      final f = home.parse('golf 100.000 km').filters;
      expect(f.mileageMaxKm, 100000);
      expect(f.hasDistance, isFalse);
    });

    test('a guest without a capital: no distance from "vicino a me"', () {
      final f = guest.parse('golf vicino a me').filters;
      expect(f.hasDistance, isFalse);
      expect(guest.parse('golf entro 30 km da milano').filters.nearProvince, 'MI');
    });
  });

  group('seller page', () {
    Future<_FakeFeed> pump(WidgetTester tester, SellerProfile? profile, SellerRef seller,
        {bool reviews = false, String? userId}) async {
      final feed = _FakeFeed();
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(SupabaseClient(
            'https://test.supabase.co',
            'anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          )),
          homeProvinceProvider.overrideWithValue('SI'),
          currentUserIdProvider.overrideWithValue(userId),
          appConfigProvider.overrideWith((ref) async => AppConfig(version: 1, values: {
                'feature_flags': {'reviews_enabled': reviews},
              })),
          sellerRepositoryProvider.overrideWithValue(_FakeSellers(profile)),
          feedRepositoryProvider.overrideWithValue(feed),
          catalogProvider.overrideWith((ref) async => _catalog),
          dealerReviewsProvider('d1').overrideWith((ref) async => DealerReviews.empty),
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
          home: SellerScreen(seller: seller),
        ),
      ));
      await tester.pumpAndSettle();
      return feed;
    }

    testWidgets('dealer: header, contacts, listings of that dealer, category tabs', (tester) async {
      const seller = SellerRef.dealer('d1');
      final feed = await pump(
        tester,
        SellerProfile(
          ref: seller,
          name: 'Auto Bianchi',
          city: 'Firenze',
          province: 'FI',
          verified: true,
          phone: '055 123456',
          hasPhone: true,
          website: 'autobianchi.it',
          memberSince: DateTime(2026, 9, 3),
        ),
        seller,
        reviews: true,
      );

      expect(find.text('Auto Bianchi'), findsNWidgets(2)); // app bar + header
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.text('Concessionario · Firenze (FI)'), findsOneWidget);
      expect(find.text('Su Carfeed da settembre 2026'), findsOneWidget);
      expect(find.text('2 annunci'), findsOneWidget);
      expect(find.text('Chiama'), findsOneWidget);
      expect(find.text('Sito'), findsOneWidget);
      expect(find.text('Recensioni'), findsOneWidget);
      expect(find.text('Firenze · 50 km da te'), findsNWidgets(2));
      expect(feed.calls.single.$2, seller);

      await tester.tap(find.text('Moto'));
      await tester.pumpAndSettle();
      expect(feed.calls.last.$1.categoryId, 'motorcycle');
      expect(feed.calls.last.$2, seller);
      expect(find.text('Ducati Monster'), findsOneWidget);

      await tester.tap(find.text('Recensioni'));
      await tester.pumpAndSettle();
      expect(find.text('Ancora nessuna recensione'), findsOneWidget);
    });

    testWidgets('private seller, guest: the number is behind sign in', (tester) async {
      const seller = SellerRef.private('u1');
      await pump(
        tester,
        const SellerProfile(ref: seller, name: 'Marco', city: 'Siena', province: 'SI', hasPhone: true),
        seller,
      );
      expect(find.text('Privato · Siena (SI)'), findsOneWidget);
      expect(find.text('Chiama'), findsNothing);
      expect(find.text('Accedi per vedere i contatti'), findsOneWidget);
      expect(find.text('Recensioni'), findsNothing);
    });

    testWidgets('nothing online: not available', (tester) async {
      await pump(tester, null, const SellerRef.private('u2'));
      expect(find.text('Profilo non disponibile'), findsOneWidget);
    });
  });

  test('listing detail reads the private seller name', () {
    final l = ListingDetail.fromRow({
      'id': 'l1',
      'seller_type': 'private',
      'owner_id': 'u1',
      'category_id': 'car',
      'province': 'SI',
      'seller': {'display_name': 'Marco', 'avatar_path': null},
    });
    expect(l.sellerDisplayName, 'Marco');
    final item = l.toFeedItem();
    expect(item.sellerName, 'Marco');
    expect(item.sellerPageId, 'u1');
    expect(FeedItem.fromRow({
      'id': 'x',
      'seller_type': 'dealer',
      'published_at': '2026-10-01T00:00:00Z',
      'owner_id': 'u9',
      'dealer_id': 'd1',
      'dealer': {'display_name': 'Auto Bianchi'},
    }).sellerPageId, 'd1');
  });
}
