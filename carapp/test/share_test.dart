import 'package:carapp/core/analytics/event_tracker.dart';
import 'package:carapp/core/config/app_config.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/features/listing/data/listing_detail.dart';
import 'package:carapp/features/listing/state/listing_providers.dart';
import 'package:carapp/features/listing/ui/listing_screen.dart';
import 'package:carapp/features/share/share_listing.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = '608044f2-ccdf-413a-b3c0-3cbc47100b3d';

AppConfig _config(Object? baseUrl) => AppConfig(version: 1, values: {
      'share': {'base_url': baseUrl},
    });

class _FakeTracker implements EventTracker {
  final events = <(AnalyticsEvent, String?)>[];

  @override
  void track(AnalyticsEvent event, {String? listingId, num? value}) => events.add((event, listingId));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('links', () {
    test('share site when base_url is set (trailing slash dropped)', () {
      expect(listingShareLink(_config('https://carfeed.pages.dev/'), _id),
          'https://carfeed.pages.dev/l/$_id');
    });

    test('app link while the site is not online (null, empty or not https)', () {
      for (final base in [null, '', 'http://insecure.example', 42]) {
        expect(listingShareLink(_config(base), _id), 'carfeed://app/listing/$_id');
      }
      expect(listingShareLink(AppConfig.empty, _id), 'carfeed://app/listing/$_id');
    });

    test('summary skips what is missing', () {
      expect(
        listingShareSummary(
            makeName: 'Volkswagen', modelName: 'Golf', year: 2019, priceCents: 1490000, city: 'Milano'),
        'Volkswagen Golf · 2019 · € 14.900 · Milano',
      );
      expect(listingShareSummary(makeName: 'Fiat', modelName: null, priceCents: 690000), 'Fiat · € 6.900');
    });
  });

  group('share button on the listing', () {
    late List<Map<Object?, Object?>> calls;
    late String answer;
    late _FakeTracker tracker;

    setUp(() {
      calls = [];
      answer = 'com.whatsapp';
      tracker = _FakeTracker();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async {
          calls.add(call.arguments as Map<Object?, Object?>);
          return answer;
        },
      );
    });

    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null));

    Widget app() => ProviderScope(
          overrides: [
            supabaseProvider.overrideWithValue(SupabaseClient(
              'https://test.supabase.co',
              'anon',
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            )),
            currentUserProvider.overrideWithValue(null),
            eventTrackerProvider.overrideWithValue(tracker),
            appConfigProvider.overrideWith((ref) async => _config('https://carfeed.pages.dev')),
            listingDetailProvider(_id).overrideWith((ref) async => ListingDetail.fromRow({
                  'id': _id,
                  'seller_type': 'private',
                  'owner_id': 'u1',
                  'category_id': 'car',
                  'year': 2017,
                  'price_cents': 690000,
                  'city': 'Milano',
                  'make': {'name': 'Fiat'},
                  'model': {'name': 'Panda'},
                })),
            listingQuestionsProvider(_id).overrideWith((ref) async => const []),
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
            home: ListingScreen(id: _id),
          ),
        );

    testWidgets('opens the share sheet with text and link, tracks the share', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Condividi'));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single['text'],
          "Fiat Panda · 2017 · € 6.900 · Milano\nGuarda l'annuncio su Carfeed: https://carfeed.pages.dev/l/$_id");
      expect(calls.single['subject'], 'Fiat Panda · 2017 · € 6.900 · Milano');
      expect(tracker.events, [(AnalyticsEvent.share, _id)]);
    });

    testWidgets('a dismissed sheet is not counted', (tester) async {
      answer = '';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Condividi'));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(tracker.events, isEmpty);
    });
  });
}
