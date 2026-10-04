import 'package:carapp/core/config/app_config.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/features/listing/data/listing_detail.dart';
import 'package:carapp/features/listing/state/listing_providers.dart';
import 'package:carapp/features/listing/ui/listing_screen.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:carapp/features/onboarding/state/onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = 'l1';

final _listing = ListingDetail.fromRow({
  'id': _id,
  'seller_type': 'dealer',
  'owner_id': 'u1',
  'category_id': 'car',
  'published_at': '2026-09-01T10:00:00Z',
  'version': '1.6 TDI Life',
  'year': 2019,
  'mileage_km': 78400,
  'price_cents': 1490000,
  'fuel_type': 'diesel',
  'transmission': 'manual',
  'power_kw': 85,
  'euro_class': 6,
  'color': 'Grigio',
  'owners_count': 1,
  'has_service_history': true,
  'warranty_months': 12,
  'description': 'Unico proprietario, tagliandi in concessionaria. ' * 20,
  'city': 'Milano',
  'province': 'MI',
  'make': {'name': 'Volkswagen'},
  'model': {'name': 'Golf'},
  'dealer': {
    'id': 'd1',
    'display_name': 'Auto Bianchi Milano',
    'city': 'Milano',
    'province': 'MI',
    'vat_verified_at': '2026-01-01T00:00:00Z',
  },
  'media': [],
});

Widget _app(ListingDetail? listing, {List<ListingQuestion> questions = const []}) {
  return ProviderScope(
    overrides: [
      homeProvinceProvider.overrideWithValue(null),
        supabaseProvider.overrideWithValue(SupabaseClient(
        'https://test.supabase.co',
        'anon',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      )),
      currentUserProvider.overrideWithValue(null),
      appConfigProvider.overrideWith((ref) async => AppConfig.empty),
      listingDetailProvider(_id).overrideWith((ref) async => listing),
      listingQuestionsProvider(_id).overrideWith((ref) async => questions),
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
}

void main() {
  for (final size in const [Size(360, 640), Size(430, 932)]) {
    testWidgets('renders a full listing at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(_listing, questions: [
        ListingQuestion(
          id: 'q1',
          question: 'Ha mai avuto incidenti?',
          answer: 'No, mai.',
          createdAt: DateTime(2026, 9, 2),
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Volkswagen Golf'), findsOneWidget);
      expect(find.text('€ 14.900'), findsWidgets);

      // Scroll through everything: layout errors would fail the test.
      await tester.dragUntilVisible(
        find.text('Fai una domanda'),
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      expect(find.text('Quanto spendi davvero'), findsOneWidget);
      expect(find.text('Diesel'), findsWidgets);
      expect(find.text('Euro 6'), findsOneWidget);
      expect(find.text('12 mesi'), findsOneWidget);
      expect(find.text('Auto Bianchi Milano'), findsOneWidget);
      expect(find.text('Partita IVA verificata'), findsOneWidget);
      expect(find.text('Ha mai avuto incidenti?'), findsOneWidget);
      expect(find.text('Mostra tutto'), findsOneWidget);
    });
  }

  testWidgets('shows the not-available state when the listing is gone', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();
    expect(find.text('Annuncio non disponibile'), findsOneWidget);
  });
}
