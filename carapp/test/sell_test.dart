import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:carapp/core/config/app_config.dart';
import 'package:carapp/core/storage/preferences.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/core/theme/app_theme.dart';
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
import 'package:carapp/features/sell/ui/edit_media_screen.dart';
import 'package:carapp/features/sell/ui/sell_start_screen.dart';
import 'package:carapp/features/sell/ui/shots_screen.dart';
import 'package:carapp/features/sell/ui/silhouette.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  EditableMedia? editable;
  final edits = <({String listingId, bool video, int? durationMs, List<Map<String, String>> photos})>[];
  PublishFailure? failEdit;

  @override
  Future<EditableMedia?> editableMedia(String listingId) async => editable;

  @override
  Future<void> applyMediaEdit({
    required String listingId,
    required bool video,
    int? videoDurationMs,
    required List<Map<String, String>> photos,
  }) async {
    if (failEdit != null) throw PublishException(failEdit!);
    edits.add((listingId: listingId, video: video, durationMs: videoDurationMs, photos: photos));
  }
}

const _online = EditableMedia(
  categoryId: 'car',
  coverPath: 'l9/cover.jpg',
  photos: [
    (id: 'm1', path: 'l9/a.jpg', step: 'front'),
    (id: 'm2', path: 'l9/b.jpg', step: 'front'), // second for the same slot: "Altre foto"
    (id: 'm3', path: 'l9/c.jpg', step: 'rear'),
    (id: 'm4', path: 'l9/d.jpg', step: 'left_side'), // old step id: "Altre foto"
  ],
);

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
          ['front', 'right_side', 'left_side', 'rear', 'interior_dashboard']);
      expect(d.readyIn(_carSteps), isFalse);

      final shots = {
        for (final s in _carSteps.where((s) => s.required))
          s.id: Shot(stepId: s.id, kind: ShotKind.video, file: '${s.id}.mp4'),
      };
      d = d.copyWith(
        shots: shots,
        details: _complete,
        photos: const [
          Shot(stepId: 'extra', kind: ShotKind.photo, file: 'x.jpg'),
          Shot(stepId: 'trunk', kind: ShotKind.photo, file: 't.jpg'),
          Shot(stepId: 'front_three_quarter', kind: ShotKind.photo, file: 'f.jpg'),
        ],
      );
      expect(d.readyIn(_carSteps), isTrue);
      expect(d.videosIn(_carSteps).map((s) => s.stepId),
          ['front', 'right_side', 'left_side', 'rear', 'interior_dashboard']);
      // Slots in slot order, then the others.
      expect(d.carousel(PhotoSlot.defaultsFor('car')).map((p) => p.file), ['f.jpg', 't.jpg', 'x.jpg']);

      final key = d.mediaKey;
      final back = SellDraft.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
      expect(back.mediaKey, key);
      expect(back.details.priceCents, 1490000);
      expect(back.details.attributes['novice_ok'], isTrue);
      expect(back.photos.map((p) => p.stepId), ['extra', 'trunk', 'front_three_quarter']);

      final retaken = d.copyWith(shots: {...d.shots, 'rear': const Shot(stepId: 'rear', kind: ShotKind.video, file: 'r2.mp4')});
      expect(retaken.mediaKey, isNot(key));
      expect(d.copyWith(photos: const []).mediaKey, key, reason: 'photos do not change the video');
    });

    test('a step is never a photo: an old photo step goes to the carousel and is to film again', () {
      final old = SellDraft(id: 'd', categoryId: 'car', createdAt: DateTime(2026), shots: const {
        'front_three_quarter': Shot(stepId: 'front_three_quarter', kind: ShotKind.video, file: 'f.mp4'),
        'rear': Shot(stepId: 'rear', kind: ShotKind.photo, file: 'r.jpg'),
        'left_side': Shot(stepId: 'left_side', kind: ShotKind.photo, file: 'l.jpg'),
      });
      final d = old.normalized(_carSteps, PhotoSlot.defaultsFor('car'));
      expect(d.shots.keys, ['front']);
      expect(d.shots['front']!.file, 'f.mp4');
      expect(d.photoFor('rear')!.file, 'r.jpg');
      expect(d.extraPhotos.single.file, 'l.jpg');
      expect(d.missingIn(_carSteps).map((s) => s.id), ['right_side', 'left_side', 'rear', 'interior_dashboard']);
      // A catalog still on the old step leaves the clip alone.
      final same = SellDraft(id: 'd', categoryId: 'car', createdAt: DateTime(2026), shots: const {
        'front_three_quarter': Shot(stepId: 'front_three_quarter', kind: ShotKind.video, file: 'f.mp4'),
      });
      expect(identical(same.normalized(const [CaptureStep(id: 'front_three_quarter')], const []), same), isTrue);
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
      expect(_carSteps.first.silhouette, 'car_front');
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

    /// Every required step filmed, plus the guided rear photo.
    Future<void> shootAll() async {
      for (final s in _carSteps.where((s) => s.required)) {
        await ctrl().addClip(s.id, await cameraFile('${s.id}.mp4'));
      }
      await ctrl().addPhoto('rear', await cameraFile('rear.jpg'), fromCamera: true);
    }

    test('a shot moves into the draft folder, gets a thumbnail, is saved on the phone', () async {
      await ctrl().start('car');
      final id = st().draft!.id;
      final raw = await cameraFile('front.mp4');
      await ctrl().addClip('front', raw);

      final shot = st().draft!.shots['front']!;
      final dir = await media.draftDir(id);
      expect(File(raw).existsSync(), isFalse);
      expect(File('${dir.path}/${shot.file}').existsSync(), isTrue);
      expect(File('${dir.path}/${shot.thumb}').existsSync(), isTrue);
      expect(ctrl().savedDraft()!.shots.keys, ['front']);

      // Retake: the old files go.
      await ctrl().addClip('front', await cameraFile('front2.mp4'));
      expect(File('${dir.path}/${shot.file}').existsSync(), isFalse);
      expect(File('${dir.path}/${shot.thumb}').existsSync(), isFalse);
      expect(st().draft!.shots['front']!.file, isNot(shot.file));
    });

    test('resume the saved draft; another category asks for a new one', () async {
      await ctrl().start('car');
      final id = st().draft!.id;
      await ctrl().addClip('rear', await cameraFile('rear.mp4'));

      await ctrl().start('car');
      expect(st().draft!.id, id);
      expect(st().draft!.shots, contains('rear'));
      expect(st().slots.first.id, 'front_three_quarter');

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
          ['front', 'right_side', 'left_side', 'rear', 'interior_dashboard']);
      expect(repo.uploads, ['video.mp4', 'cover.jpg', 'photo-01-rear.jpg']);
      expect(st().phase, MediaPhase.ready);
      expect(st().progress, 1);
      expect(st().draft!.videoDurationMs, 5 * 5000 - 4 * 600);

      // Again: nothing to do.
      await ctrl().prepareMedia();
      expect(media.renders, hasLength(1));
      expect(repo.uploads, hasLength(3));
    });

    test('retaking a step after the video makes it again and drops stale uploads', () async {
      await ctrl().start('car');
      await shootAll();
      await ctrl().prepareMedia();

      // An optional step filmed: new video; the rear photo removed.
      await ctrl().addClip('engine_bay', await cameraFile('engine.mp4'));
      await ctrl().removePhoto(st().draft!.photoFor('rear')!.file);
      await ctrl().prepareMedia();

      expect(media.renders, hasLength(2));
      expect(media.renders.last, hasLength(6));
      expect(repo.uploads.sublist(3), ['video.mp4', 'cover.jpg']);
      expect(repo.removed, ['photo-01-rear.jpg']);
      expect(st().draft!.uploaded.keys, unorderedEquals(['video.mp4', 'cover.jpg']));
    });

    test('photos: copied from the gallery, slots before the others, no new video, removable, max 10 others', () async {
      await ctrl().start('car');
      await shootAll();
      await ctrl().prepareMedia();

      final picked = [for (var i = 0; i < 2; i++) await cameraFile('gallery-$i.jpg')];
      expect(await ctrl().addExtraPhotos(picked), 2);
      expect(File(picked.first).existsSync(), isTrue, reason: 'gallery files are copied, not moved');
      final extras = st().draft!.extraPhotos;
      expect(extras.map((e) => e.stepId), ['extra', 'extra']);
      expect(File('${media.root.path}/${st().draft!.id}/${extras.first.file}').existsSync(), isTrue);

      await ctrl().prepareMedia();
      expect(media.renders, hasLength(1), reason: 'photos do not change the video');
      expect(repo.uploads.sublist(3), ['photo-02-extra.jpg', 'photo-03-extra.jpg']);

      // A slot photo from the gallery goes before the others; retaking the
      // rear one replaces it. Still no new video.
      final rear = st().draft!.photoFor('rear')!.file;
      await ctrl().addPhoto('front', await cameraFile('front.jpg'), fromCamera: false);
      await ctrl().addPhoto('rear', await cameraFile('rear2.jpg'), fromCamera: true);
      expect(File('${media.root.path}/${st().draft!.id}/$rear').existsSync(), isFalse);
      expect(st().draft!.photos.where((p) => p.stepId == 'rear'), hasLength(1));
      await ctrl().prepareMedia();
      expect(media.renders, hasLength(1));
      expect(st().draft!.uploaded.keys, containsAll(['photo-01-front.jpg', 'photo-02-rear.jpg', 'photo-03-extra.jpg', 'photo-04-extra.jpg']));

      await ctrl().removePhoto(extras.first.file);
      await ctrl().prepareMedia();
      expect(st().draft!.extraPhotos.single.file, extras.last.file);
      // Names shift when a slot photo comes before (renamed uploads go);
      // the removed photo's name goes last.
      expect(repo.removed.last, 'photo-04-extra.jpg');
      expect(st().draft!.uploaded.keys,
          unorderedEquals(['video.mp4', 'cover.jpg', 'photo-01-front.jpg', 'photo-02-rear.jpg', 'photo-03-extra.jpg']));

      // Survives a restart of the app.
      expect(ctrl().savedDraft()!.extraPhotos.single.file, extras.last.file);

      final many = [for (var i = 0; i < 12; i++) await cameraFile('many-$i.jpg')];
      expect(await ctrl().addExtraPhotos(many), SellDraft.maxExtras - 1);
      expect(st().draft!.extraPhotos, hasLength(SellDraft.maxExtras));
      expect(await ctrl().addExtraPhotos([many.first]), 0);
    });

    test('a draft from before migration 15 keeps its front shot', () async {
      final old = SellDraft(id: 'd1', categoryId: 'car', createdAt: DateTime(2026), shots: const {
        'front_three_quarter': Shot(stepId: 'front_three_quarter', kind: ShotKind.video, file: 'f.mp4'),
      });
      await prefs.setString(PrefKeys.sellDraft, jsonEncode(old.toJson()));
      await ctrl().start('car');
      expect(st().draft!.shots.keys, ['front']);
      expect(st().draft!.shots['front']!.file, 'f.mp4');
    });

    group('edit media of an online listing', () {
      SellController edit() => c.read(mediaEditControllerProvider.notifier);
      SellState es() => c.read(mediaEditControllerProvider);

      test('starts from the online photos, the video kept, nothing to save', () async {
        repo.editable = _online;
        await edit().startEdit('l9');
        final d = es().draft!;
        expect(d.editing, isTrue);
        expect(d.keepsVideo, isTrue);
        expect(d.missingIn(es().steps), isEmpty);
        expect(d.readyIn(es().steps), isTrue);
        expect(d.hasEdits, isFalse);
        expect(d.photoFor('front')!.mediaId, 'm1');
        expect(d.photoFor('rear')!.mediaId, 'm3');
        expect(d.extraPhotos.map((p) => p.mediaId), ['m2', 'm4']);
        expect(d.publishedCover, 'l9/cover.jpg');

        // Not the user's.
        repo.editable = null;
        await expectLater(edit().startEdit('other'), throwsA(isA<PublishException>()));
      });

      test('photos only: no video, only the new photo uploaded, the carousel sent in order', () async {
        repo.editable = _online;
        await edit().startEdit('l9');
        await edit().removePhoto(es().draft!.photoFor('rear')!.file);
        await edit().addPhoto('trunk', await cameraFile('trunk.jpg'), fromCamera: false);
        expect(es().draft!.hasEdits, isTrue);

        await edit().applyEdit();
        expect(media.renders, isEmpty);
        expect(repo.uploads, ['photo-02-trunk.jpg']);
        final sent = repo.edits.single;
        expect(sent.listingId, 'l9');
        expect(sent.video, isFalse);
        expect(sent.photos, [
          {'media_id': 'm1'},
          {'file': 'photo-02-trunk.jpg'},
          {'media_id': 'm2'},
          {'media_id': 'm4'},
        ]);
        expect(es().draft, isNull);
        expect(prefs.getString(PrefKeys.mediaEditDraft), isNull);
      });

      test('a new video: every step again, rendered and uploaded; partial = not ready', () async {
        repo.editable = _online;
        await edit().startEdit('l9');
        await edit().addClip('front', await cameraFile('f.mp4'));
        expect(es().draft!.keepsVideo, isFalse);
        expect(es().draft!.readyIn(es().steps), isFalse);
        await expectLater(edit().applyEdit(), throwsA(isA<PublishException>()));

        // Back to the online video.
        await edit().keepPublishedVideo();
        expect(es().draft!.keepsVideo, isTrue);
        expect(es().draft!.hasEdits, isFalse);

        for (final s in _carSteps.where((s) => s.required)) {
          await edit().addClip(s.id, await cameraFile('${s.id}.mp4'));
        }
        await edit().applyEdit();
        expect(media.renders, hasLength(1));
        expect(repo.uploads, ['video.mp4', 'cover.jpg']);
        final sent = repo.edits.single;
        expect(sent.video, isTrue);
        expect(sent.durationMs, 5 * 5000 - 4 * 600);
        expect(sent.photos.map((p) => p['media_id']), ['m1', 'm3', 'm2', 'm4']);
      });

      test('a new listing in progress is never touched; an edit resumes', () async {
        await ctrl().start('car');
        await ctrl().addClip('front', await cameraFile('mine.mp4'));
        repo.editable = _online;
        await edit().startEdit('l9');
        await edit().addPhoto(PhotoSlot.extra, await cameraFile('x.jpg'), fromCamera: true);
        expect(ctrl().savedDraft()!.shots.keys, ['front']);
        expect(ctrl().savedDraft()!.editing, isFalse);

        // Leaving and coming back to the same listing keeps the changes.
        repo.editable = null;
        final again = ProviderContainer(overrides: [
          sellMediaProvider.overrideWithValue(media),
          sellRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          appConfigProvider.overrideWith((ref) async => AppConfig.empty),
        ]);
        addTearDown(again.dispose);
        await again.read(mediaEditControllerProvider.notifier).startEdit('l9');
        expect(again.read(mediaEditControllerProvider).draft!.extraPhotos, hasLength(3));
      });

      test('a refusal keeps the edit for another try', () async {
        repo.editable = _online;
        await edit().startEdit('l9');
        await edit().removePhoto(es().draft!.photoFor('front')!.file);
        repo.failEdit = PublishFailure.notEditable;
        await expectLater(
          edit().applyEdit(),
          throwsA(isA<PublishException>().having((e) => e.failure, 'failure', PublishFailure.notEditable)),
        );
        expect(es().draft!.hasEdits, isTrue);
        expect(prefs.getString(PrefKeys.mediaEditDraft), isNotNull);
      });
    });

    test('a retake while the video is being made restarts it', () async {
      await ctrl().start('car');
      await shootAll();
      media.renderGate = Completer();
      final run = ctrl().prepareMedia();
      await Future<void>.delayed(Duration.zero);
      expect(st().phase, MediaPhase.rendering);

      await ctrl().addClip('engine_bay', await cameraFile('engine.mp4'));
      media.renderGate!.complete();
      media.renderGate = null;
      await run;

      expect(media.renders, hasLength(2));
      expect(media.renders.last, hasLength(6));
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
      expect(repo.published.single, (id, 5 * 5000 - 4 * 600));
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
          // The app's theme: full-width buttons must not break rows.
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
        'rear': Shot(stepId: 'rear', kind: ShotKind.video, file: 'rear.mp4'),
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
          await container.read(sellControllerProvider.notifier).addClip(s.id, f.path);
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
        final f = File('${tmp.path}/left.mp4')..writeAsStringSync('x');
        await container.read(sellControllerProvider.notifier).addClip('left_side', f.path);
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

    testWidgets('shots: guided photos, a slot from the gallery, other photos', (tester) async {
      tester.view.physicalSize = const Size(430, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final picked = File('${tmp.path}/gallery.jpg')..writeAsStringSync('jpg');
      final asked = <(bool, int)>[];
      late ProviderContainer container;
      await tester.pumpWidget(app(
        Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const ShotsScreen();
        }),
        more: [
          photoPickerProvider.overrideWithValue(({required camera, required limit, required maxSide}) async {
            asked.add((camera, limit));
            return [picked.path];
          }),
        ],
      ));
      await tester.runAsync(() => container.read(sellControllerProvider.notifier).start('car'));
      await tester.pumpAndSettle();

      expect(find.text('Foto per il carosello'), findsOneWidget);
      expect(find.text('Anteriore 3/4'), findsOneWidget);
      expect(find.text('Bagagliaio'), findsOneWidget);

      // A slot: hint, then gallery.
      await tester.tap(find.text('Bagagliaio'));
      await tester.pumpAndSettle();
      expect(find.text('Aperto e vuoto, inquadrato dall\'alto'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Scegli dalla galleria'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(asked, [(false, 1)]);
      expect(container.read(sellControllerProvider).draft!.photoFor('trunk'), isNotNull);

      // Other photos.
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Scegli dalla galleria'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(asked.last, (false, SellDraft.maxExtras));
      expect(container.read(sellControllerProvider).draft!.extraPhotos, hasLength(1));

      // Guided camera for every missing slot.
      await tester.tap(find.text('Scatta con la guida'));
      await tester.pumpAndSettle();
      expect(find.text('capture photos=1'), findsOneWidget);
    });

    testWidgets('edit media: video kept, reshoot opens its camera, save, leave asks', (tester) async {
      tester.view.physicalSize = const Size(430, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo.editable = _online;
      // Online photos go through the image cache, which wants a folder.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => tmp.path,
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null));
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('my listings'))),
        GoRoute(path: '/listing/:id/media', builder: (_, s) => EditMediaScreen(listingId: s.pathParameters['id']!)),
        GoRoute(path: '/listing/:id/media/capture', builder: (_, s) => Text('edit capture ${s.uri.query}')),
      ]);
      await tester.pumpWidget(ProviderScope(
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
      router.push('/listing/l9/media');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(find.text('Foto e video'), findsOneWidget);
      expect(find.byKey(const ValueKey('published-video')), findsOneWidget);
      final save = find.widgetWithText(FilledButton, 'Salva foto e video');
      expect(tester.widget<FilledButton>(save).onPressed, isNull, reason: 'nothing changed');

      await tester.tap(find.text('Rifai il video'));
      await tester.pumpAndSettle();
      expect(find.text('edit capture '), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      // Remove the rear photo: something to save; leaving asks first.
      await tester.tap(find.text('Posteriore'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Elimina'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

      await tester.tap(find.byTooltip('Indietro'));
      await tester.pumpAndSettle();
      expect(find.text('Uscire senza salvare?'), findsOneWidget);
      await tester.tap(find.text('Resta'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(save);
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(repo.edits.single.photos.map((p) => p['media_id']), ['m1', 'm2', 'm4']);
      expect(find.text('my listings'), findsOneWidget);
      expect(find.text('Foto e video aggiornati'), findsOneWidget);
      // The snackbar and the image cache keep timers: let them run out.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
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
          await container.read(sellControllerProvider.notifier).addClip(s.id, f.path);
        }
      });

      final router = GoRouter(initialLocation: '/details', routes: [
        GoRoute(path: '/details', builder: (_, _) => const SellDetailsScreen()),
        GoRoute(path: '/sell/done/:id', builder: (_, s) => Text('done ${s.pathParameters['id']}')),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          // The app's theme: full-width buttons must not break rows.
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
