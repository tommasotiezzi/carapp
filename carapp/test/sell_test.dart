import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:carapp/core/config/app_config.dart';
import 'package:carapp/core/storage/preferences.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/features/listing/data/listing_detail.dart';
import 'package:carapp/features/listing/state/listing_providers.dart';
import 'package:carapp/features/onboarding/data/catalog_repository.dart';
import 'package:carapp/features/onboarding/state/onboarding_controller.dart';
import 'package:carapp/features/search/data/catalog.dart';
import 'package:carapp/features/sell/data/capture_step.dart';
import 'package:carapp/features/sell/data/sell_draft.dart';
import 'package:carapp/features/sell/data/sell_media.dart';
import 'package:carapp/features/sell/data/sell_repository.dart';
import 'package:carapp/features/sell/state/sell_controller.dart';
import 'package:carapp/features/sell/ui/sell_details_screen.dart';
import 'package:carapp/features/sell/ui/sell_done_screen.dart';
import 'package:carapp/features/sell/ui/sell_start_screen.dart';
import 'package:carapp/features/sell/ui/shots_screen.dart';
import 'package:carapp/features/sell/ui/silhouette.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _carSteps = CaptureStep.defaultsFor('car');

/// Files in a temp folder; the "video" is just the clip names joined.
class FakeSellMedia implements SellMedia {
  FakeSellMedia(this.root);

  final Directory root;
  final renders = <List<String>>[];
  Completer<void>? renderGate;
  bool failRender = false;

  @override
  Future<Directory> draftDir(String draftId) async {
    final dir = Directory('${root.path}/$draftId');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  @override
  Future<void> deleteDraftDir(String draftId) async {
    final dir = Directory('${root.path}/$draftId');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  @override
  Future<void> thumbnail({required String video, required String out, required Size size, Duration at = Duration.zero}) async =>
      File(out).writeAsStringSync('thumb of ${video.split('/').last}');

  @override
  Future<int> renderVideo({
    required String taskId,
    required List<String> clips,
    required String out,
    required int bitrate,
    required void Function(double progress) onProgress,
  }) async {
    renders.add([for (final c in clips) c.split('/').last]);
    onProgress(0.5);
    if (renderGate != null) await renderGate!.future;
    if (failRender) throw Exception('encoder');
    File(out).writeAsStringSync(clips.join(','));
    onProgress(1);
    return clips.length * 5000 - (clips.length - 1) * 600;
  }

  @override
  Future<void> cancel(String taskId) async {}
}

class FakeSellRepository implements SellRepository {
  final uploads = <String>[];
  final removed = <String>[];
  final saved = <(SellDraft, String?)>[];
  final published = <(String, int?)>[];
  final phones = <String>[];
  var ageConsents = 0;
  PublishFailure? failPublish;
  SellerProfile profile = const SellerProfile(city: 'Milano', phone: '3331234567');

  @override
  Future<List<CaptureStep>> captureSteps(String categoryId) async => CaptureStep.defaultsFor(categoryId);

  @override
  Future<SellerProfile> sellerProfile() async => profile;

  @override
  Future<void> saveListing(SellDraft draft, {String? dealerId}) async => saved.add((draft, dealerId));

  @override
  Future<void> upload({required String draftId, required File file, required String name, required String contentType}) async {
    expect(file.existsSync(), isTrue, reason: '$name must exist on the phone');
    uploads.add(name);
  }

  @override
  Future<void> removeUploads(String draftId, List<String> names) async => removed.addAll(names);

  @override
  Future<void> saveSellerPhone(String phone) async => phones.add(phone);

  @override
  Future<bool> hasSellerAgeConsent() async => false;

  @override
  Future<void> recordSellerAgeConsent() async => ageConsents++;

  @override
  Future<void> publish({required String draftId, int? videoDurationMs}) async {
    if (failPublish != null) throw PublishException(failPublish!);
    published.add((draftId, videoDurationMs));
  }
}

const _complete = SellDetails(
  makeId: 'vw',
  modelId: 'golf',
  year: 2019,
  mileageKm: 78400,
  priceCents: 1490000,
  fuelType: 'diesel',
  city: ' Milano ',
  province: 'mi',
  attributes: {'novice_ok': true, 'body_type': null},
);

void main() {
  group('SellDraft', () {
    test('json round trip, missing steps, ready, media key', () {
      var d = SellDraft(id: 'd1', categoryId: 'car', createdAt: DateTime(2026, 10, 4));
      expect(d.missingIn(_carSteps).map((s) => s.id),
          ['front_three_quarter', 'right_side', 'left_side', 'rear', 'interior_dashboard']);
      expect(d.readyIn(_carSteps), isFalse);

      final shots = {
        for (final s in _carSteps.where((s) => s.required))
          s.id: Shot(stepId: s.id, kind: s.id == 'rear' ? ShotKind.photo : ShotKind.video, file: '${s.id}.x'),
      };
      d = d.copyWith(shots: shots, details: _complete);
      expect(d.readyIn(_carSteps), isTrue);
      expect(d.videosIn(_carSteps).map((s) => s.stepId),
          ['front_three_quarter', 'right_side', 'left_side', 'interior_dashboard']);
      expect(d.photosIn(_carSteps).single.stepId, 'rear');

      final key = d.mediaKey;
      final back = SellDraft.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
      expect(back.mediaKey, key);
      expect(back.details.priceCents, 1490000);
      expect(back.details.attributes['novice_ok'], isTrue);
      expect(back.shots['rear']!.kind, ShotKind.photo);

      final retaken = d.copyWith(shots: {...d.shots, 'rear': const Shot(stepId: 'rear', kind: ShotKind.video, file: 'r2.mp4')});
      expect(retaken.mediaKey, isNot(key));
    });

    test('only photos is not enough: the feed needs a video', () {
      final d = SellDraft(id: 'd', categoryId: 'car', createdAt: DateTime(2026), shots: {
        for (final s in _carSteps.where((s) => s.required))
          s.id: Shot(stepId: s.id, kind: ShotKind.photo, file: '${s.id}.jpg'),
      });
      expect(d.missingIn(_carSteps), isEmpty);
      expect(d.readyIn(_carSteps), isFalse);
    });

    test('details: required fields and the listing row', () {
      expect(SellDetails.empty.missing,
          ['make_id', 'model_id', 'year', 'mileage_km', 'price_cents', 'fuel_type', 'city', 'province']);
      expect(_complete.isComplete, isTrue);
      final row = _complete.toListingRow();
      expect(row['city'], 'Milano');
      expect(row['province'], 'MI');
      expect(row['attributes'], {'novice_ok': true});
      expect(row.containsKey('status'), isFalse);
      expect(row.containsKey('video_path'), isFalse);
    });

    test('step defaults match the database seed', () {
      expect(CaptureStep.defaultsFor('motorcycle').where((s) => s.required).length, 4);
      expect(_carSteps.first.silhouette, 'car_front_3q');
      expect(_carSteps.every((s) => s.silhouette == null || Silhouette.known.contains(s.silhouette)), isTrue);
      final parsed = CaptureStep.listFromJson(jsonDecode(
          '[{"id":"rear","kind":"video","seconds":5,"silhouette":"car_rear","plate_tip":true,"required":true}]'));
      expect(parsed.single.plateTip, isTrue);
    });
  });

  test('ThousandsFormatter', () {
    const f = ThousandsFormatter();
    expect(f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '78400')).text, '78.400');
    expect(f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '1.4900a0')).text, '149.000');
    expect(ThousandsFormatter.parse('14.900'), 14900);
    expect(ThousandsFormatter.parse(''), isNull);
  });

  group('SellController', () {
    late Directory tmp;
    late FakeSellMedia media;
    late FakeSellRepository repo;
    late ProviderContainer c;
    late SharedPreferences prefs;

    Future<String> cameraFile(String name) async {
      final f = File('${tmp.path}/camera-$name');
      await f.writeAsString('raw $name');
      return f.path;
    }

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('sell');
      media = FakeSellMedia(Directory('${tmp.path}/drafts'));
      repo = FakeSellRepository();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(overrides: [
        sellMediaProvider.overrideWithValue(media),
        sellRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWith((ref) async => AppConfig.empty),
      ]);
      await c.read(appConfigProvider.future);
    });

    tearDown(() {
      c.dispose();
      tmp.deleteSync(recursive: true);
    });

    SellController ctrl() => c.read(sellControllerProvider.notifier);
    SellState st() => c.read(sellControllerProvider);

    Future<void> shootAll({String photoStep = 'rear'}) async {
      for (final s in _carSteps.where((s) => s.required)) {
        final kind = s.id == photoStep ? ShotKind.photo : ShotKind.video;
        await ctrl().addShot(s.id, kind, await cameraFile('${s.id}.${kind == ShotKind.photo ? 'jpg' : 'mp4'}'));
      }
    }

    test('a shot moves into the draft folder, gets a thumbnail, is saved on the phone', () async {
      await ctrl().start('car');
      final id = st().draft!.id;
      final raw = await cameraFile('front.mp4');
      await ctrl().addShot('front_three_quarter', ShotKind.video, raw);

      final shot = st().draft!.shots['front_three_quarter']!;
      final dir = await media.draftDir(id);
      expect(File(raw).existsSync(), isFalse);
      expect(File('${dir.path}/${shot.file}').existsSync(), isTrue);
      expect(File('${dir.path}/${shot.thumb}').existsSync(), isTrue);
      expect(ctrl().savedDraft()!.shots.keys, ['front_three_quarter']);

      // Retake: the old files go.
      await ctrl().addShot('front_three_quarter', ShotKind.photo, await cameraFile('front.jpg'));
      expect(File('${dir.path}/${shot.file}').existsSync(), isFalse);
      expect(st().draft!.shots['front_three_quarter']!.kind, ShotKind.photo);
    });

    test('resume the saved draft; another category asks for a new one', () async {
      await ctrl().start('car');
      final id = st().draft!.id;
      await ctrl().addShot('rear', ShotKind.photo, await cameraFile('rear.jpg'));

      await ctrl().start('car');
      expect(st().draft!.id, id);
      expect(st().draft!.shots, contains('rear'));

      await ctrl().start('motorcycle');
      expect(st().draft!.id, isNot(id));
      expect(st().draft!.shots, isEmpty);
      expect(Directory('${media.root.path}/$id').existsSync(), isFalse);
    });

    test('media: videos joined in step order, then video, cover and photos uploaded', () async {
      await ctrl().start('car');
      await shootAll();
      await ctrl().prepareMedia();

      expect(media.renders.single.map((f) => f.split('-').first),
          ['front_three_quarter', 'right_side', 'left_side', 'interior_dashboard']);
      expect(repo.uploads, ['video.mp4', 'cover.jpg', 'photo-01-rear.jpg']);
      expect(st().phase, MediaPhase.ready);
      expect(st().progress, 1);
      expect(st().draft!.videoDurationMs, 4 * 5000 - 3 * 600);

      // Again: nothing to do.
      await ctrl().prepareMedia();
      expect(media.renders, hasLength(1));
      expect(repo.uploads, hasLength(3));
    });

    test('retaking a step after the video makes it again and drops stale uploads', () async {
      await ctrl().start('car');
      await shootAll();
      await ctrl().prepareMedia();

      // The rear photo becomes a video: new video, no carousel photo.
      await ctrl().addShot('rear', ShotKind.video, await cameraFile('rear.mp4'));
      await ctrl().prepareMedia();

      expect(media.renders, hasLength(2));
      expect(media.renders.last, hasLength(5));
      expect(repo.uploads.sublist(3), ['video.mp4', 'cover.jpg']);
      expect(repo.removed, ['photo-01-rear.jpg']);
      expect(st().draft!.uploaded.keys, unorderedEquals(['video.mp4', 'cover.jpg']));
    });

    test('a retake while the video is being made restarts it', () async {
      await ctrl().start('car');
      await shootAll();
      media.renderGate = Completer();
      final run = ctrl().prepareMedia();
      await Future<void>.delayed(Duration.zero);
      expect(st().phase, MediaPhase.rendering);

      await ctrl().addShot('engine_bay', ShotKind.video, await cameraFile('engine.mp4'));
      media.renderGate!.complete();
      media.renderGate = null;
      await run;

      expect(media.renders, hasLength(2));
      expect(media.renders.last, hasLength(5));
      expect(st().draft!.renderedFrom, st().draft!.mediaKey);
      expect(repo.uploads.where((u) => u == 'video.mp4'), hasLength(1));
    });

    test('render failure shows; publish tries again', () async {
      await ctrl().start('car');
      await shootAll();
      media.failRender = true;
      ctrl().startMedia();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(st().phase, MediaPhase.failed);

      ctrl().updateDetails(_complete);
      media.failRender = false;
      final id = await ctrl().publish(dealerId: null, newPhone: '3339998888', recordSellerAge: true);
      expect(repo.published.single.$1, id);
      expect(repo.phones, ['3339998888']);
      expect(repo.ageConsents, 1);
    });

    test('publish: row saved for the dealer, media ready, function called, draft gone', () async {
      await ctrl().start('car');
      final id = st().draft!.id;
      await shootAll();
      ctrl().updateDetails(_complete);

      final published = await ctrl().publish(dealerId: 'dealer-1');

      expect(published, id);
      expect(repo.saved.single.$2, 'dealer-1');
      expect(repo.saved.single.$1.details.priceCents, 1490000);
      expect(repo.uploads, contains('video.mp4'));
      expect(repo.published.single, (id, 4 * 5000 - 3 * 600));
      expect(prefs.getString(PrefKeys.sellDraft), isNull);
      expect(Directory('${media.root.path}/$id').existsSync(), isFalse);
      expect(st().draft, isNull);
    });

    test('publish refuses incomplete data before any request', () async {
      await ctrl().start('car');
      await shootAll();
      await expectLater(
        ctrl().publish(dealerId: null),
        throwsA(isA<PublishException>().having((e) => e.failure, 'failure', PublishFailure.incomplete)),
      );
      expect(repo.saved, isEmpty);
    });

    test('a server refusal keeps the draft for another try', () async {
      await ctrl().start('car');
      await shootAll();
      ctrl().updateDetails(_complete);
      repo.failPublish = PublishFailure.missingMedia;
      await expectLater(ctrl().publish(dealerId: null), throwsA(isA<PublishException>()));
      expect(st().draft, isNotNull);
      expect(prefs.getString(PrefKeys.sellDraft), isNotNull);
    });
  });

  group('screens', () {
    late Directory tmp;
    late FakeSellMedia media;
    late FakeSellRepository repo;
    late SharedPreferences prefs;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('sellui');
      media = FakeSellMedia(Directory('${tmp.path}/drafts'));
      repo = FakeSellRepository();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    final catalog = Catalog(
      makes: const [CatalogMake(id: 'vw', name: 'Volkswagen', categoryId: 'car')],
      models: const [CatalogModel(id: 'golf', makeId: 'vw', name: 'Golf')],
    );

    Widget app(Widget home, {List<Override> more = const [], String initial = '/'}) {
      final router = GoRouter(initialLocation: initial, routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(path: '/sell', builder: (_, _) => const Text('start')),
        GoRoute(path: '/sell/capture', builder: (_, s) => Text('capture ${s.uri.query}')),
        GoRoute(path: '/sell/shots', builder: (_, _) => const ShotsScreen()),
        GoRoute(path: '/sell/shots/details', builder: (_, _) => const Text('details')),
        GoRoute(path: '/sell/done/:id', builder: (_, s) => Text('done ${s.pathParameters['id']}')),
        GoRoute(path: '/feed', builder: (_, _) => const Text('feed')),
      ]);
      return ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(SupabaseClient(
            'https://test.supabase.co',
            'anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          )),
          sellMediaProvider.overrideWithValue(media),
          sellRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          appConfigProvider.overrideWith((ref) async => AppConfig.empty),
          currentUserProvider.overrideWithValue(User(
            id: 'me',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: '2026-01-01',
          )),
          ...more,
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
      );
    }

    testWidgets('start: categories, tips, then capture for a new draft', (tester) async {
      await tester.pumpWidget(app(const SellStartScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Cosa vuoi vendere?'), findsOneWidget);
      expect(find.text('anche furgoni'), findsOneWidget);
      expect(find.textContaining('copri la targa'), findsOneWidget);
      expect(find.byKey(const ValueKey('sell-draft')), findsNothing);

      await tester.tap(find.text('Moto'));
      await tester.pump();
      expect(find.textContaining('Moto pulita'), findsOneWidget);

      await tester.tap(find.text('Inizia le riprese'));
      await tester.pumpAndSettle();
      expect(find.text('capture '), findsOneWidget);
    });

    testWidgets('start: a saved draft can be resumed', (tester) async {
      final draft = SellDraft(id: 'd1', categoryId: 'car', createdAt: DateTime(2026), shots: const {
        'rear': Shot(stepId: 'rear', kind: ShotKind.photo, file: 'rear.jpg'),
      });
      await prefs.setString(PrefKeys.sellDraft, jsonEncode(draft.toJson()));
      await tester.pumpWidget(app(const SellStartScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sell-draft')), findsOneWidget);
      expect(find.textContaining('1 ripresa fatta'), findsOneWidget);
      expect(find.text('Riprendi'), findsNWidgets(2));
    });

    testWidgets('shots: done, to do, optional; "Crea il video" only when ready', (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late ProviderContainer container;
      await tester.pumpWidget(app(
        Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const ShotsScreen();
        }),
      ));
      await tester.runAsync(() async {
        await container.read(sellControllerProvider.notifier).start('car');
        for (final s in _carSteps.where((s) => s.required && s.id != 'left_side')) {
          final f = File('${tmp.path}/${s.id}.mp4')..writeAsStringSync('x');
          await container.read(sellControllerProvider.notifier).addShot(s.id, ShotKind.video, f.path);
        }
      });
      await tester.pumpAndSettle();

      expect(find.text('Le tue riprese'), findsOneWidget);
      expect(find.textContaining('4 di 7 completate'), findsOneWidget);
      expect(find.text('Da fare'), findsOneWidget);
      expect(find.text('Mancano: Lato sinistro'), findsOneWidget);
      expect(find.text('Facoltativo · aumenta la fiducia'), findsOneWidget);
      expect(find.textContaining('motore acceso'), findsOneWidget);
      final create = find.widgetWithText(FilledButton, 'Crea il video');
      expect(tester.widget<FilledButton>(create).onPressed, isNull);

      await tester.runAsync(() async {
        final f = File('${tmp.path}/left.jpg')..writeAsStringSync('x');
        await container.read(sellControllerProvider.notifier).addShot('left_side', ShotKind.photo, f.path);
      });
      await tester.pumpAndSettle();
      expect(find.text('Mancano: Lato sinistro'), findsNothing);
      expect(tester.widget<FilledButton>(create).onPressed, isNotNull);

      await tester.tap(find.text('Lato sinistro'));
      await tester.pumpAndSettle();
      expect(find.text('Rifai'), findsOneWidget);
      expect(find.text('Elimina'), findsNothing); // required step
      await tester.tap(find.text('Rifai'));
      await tester.pumpAndSettle();
      expect(find.text('capture step=left_side&single=1'), findsOneWidget);
    });

    testWidgets('details: validation and publish', (tester) async {
      tester.view.physicalSize = const Size(430, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(overrides: [
        supabaseProvider.overrideWithValue(SupabaseClient(
          'https://test.supabase.co',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        )),
        sellMediaProvider.overrideWithValue(media),
        sellRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWith((ref) async => AppConfig.empty),
        catalogProvider.overrideWith((ref) async => catalog),
        makesProvider('car').overrideWith((ref) async => const [Make(id: 'vw', name: 'Volkswagen', categoryId: 'car')]),
        sellerAgeConsentProvider.overrideWith((ref) async => false),
        // "Dove sei?" = Milano: the form starts from it.
        homeProvinceProvider.overrideWithValue('MI'),
      ]);
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        await container.read(appConfigProvider.future);
        await container.read(sellControllerProvider.notifier).start('car');
        for (final s in _carSteps.where((s) => s.required)) {
          final f = File('${tmp.path}/${s.id}.mp4')..writeAsStringSync('x');
          await container.read(sellControllerProvider.notifier).addShot(s.id, ShotKind.video, f.path);
        }
      });

      final router = GoRouter(initialLocation: '/details', routes: [
        GoRoute(path: '/details', builder: (_, _) => const SellDetailsScreen()),
        GoRoute(path: '/sell/done/:id', builder: (_, s) => Text('done ${s.pathParameters['id']}')),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
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

      expect(find.text('Dati e prezzo'), findsOneWidget);
      expect(find.text('Milano'), findsOneWidget); // city from the capital
      expect(find.text('MI'), findsOneWidget); // province
      expect(find.text('Ho almeno 18 anni, oppure vendo con il consenso di un genitore'), findsOneWidget);

      await tester.tap(find.text('Pubblica annuncio'));
      await tester.pumpAndSettle();
      expect(find.text('Obbligatorio'), findsWidgets);
      expect(repo.saved, isEmpty);

      // Make and model from the pickers.
      await tester.tap(find.text('Scegli').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volkswagen').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scegli').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Golf').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Anno'), '2019');
      await tester.enterText(find.widgetWithText(TextField, 'Chilometri'), '78400');
      expect(find.text('78.400'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Diesel'));
      await tester.enterText(find.byType(TextField).at(2), '14900');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('Pubblica annuncio'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(repo.saved.single.$1.details.toListingRow(), containsPair('price_cents', 1490000));
      expect(repo.saved.single.$1.details.toListingRow(), containsPair('model_id', 'golf'));
      expect(repo.saved.single.$1.details.toListingRow(), containsPair('province', 'MI'));
      expect(repo.ageConsents, 1);
      expect(repo.published, hasLength(1));
      expect(find.textContaining('done '), findsOneWidget);
    });

    testWidgets('done: model in the title, share and open', (tester) async {
      final listing = ListingDetail.fromRow({
        'id': 'l1',
        'seller_type': 'private',
        'owner_id': 'me',
        'category_id': 'car',
        'version': '1.6 TDI',
        'year': 2019,
        'mileage_km': 78400,
        'price_cents': 1490000,
        'make': {'name': 'Volkswagen'},
        'model': {'name': 'Golf'},
      });
      await tester.pumpWidget(app(
        const SellDoneScreen(listingId: 'l1'),
        more: [listingDetailProvider('l1').overrideWith((ref) async => listing)],
      ));
      await tester.pumpAndSettle();
      expect(find.text('La tua Golf è online'), findsOneWidget);
      expect(find.textContaining('Tra 3 settimane'), findsOneWidget);
      expect(find.text('€ 14.900 · 2019 · 78.400 km'), findsOneWidget);
      expect(find.text('Condividi il link'), findsOneWidget);
      expect(find.text("Vedi l'annuncio"), findsOneWidget);
    });
  });
}
