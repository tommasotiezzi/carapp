import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/preferences.dart';
import '../../feed/state/feed_controller.dart';
import '../../listing/state/listing_providers.dart';
import '../../my_listings/state/my_listings_controller.dart';
import '../data/capture_step.dart';
import '../data/sell_draft.dart';
import '../data/sell_media.dart';
import '../data/sell_repository.dart';

/// Making the video and uploading the media, in the background while the
/// user fills "Dati e prezzo".
enum MediaPhase { idle, rendering, uploading, ready, failed }

class SellState {
  const SellState({
    this.draft,
    this.steps = const [],
    this.slots = const [],
    this.phase = MediaPhase.idle,
    this.progress = 0,
  });

  final SellDraft? draft;
  final List<CaptureStep> steps;

  /// Suggested carousel photos for the draft's category.
  final List<PhotoSlot> slots;
  final MediaPhase phase;

  /// 0..1 over rendering (first 70%) and uploading.
  final double progress;

  static const empty = SellState();

  SellState copyWith({
    SellDraft? draft,
    List<CaptureStep>? steps,
    List<PhotoSlot>? slots,
    MediaPhase? phase,
    double? progress,
  }) =>
      SellState(
        draft: draft ?? this.draft,
        steps: steps ?? this.steps,
        slots: slots ?? this.slots,
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
      );
}

/// The listing being created, from the first shot to "è online".
/// The draft is saved on the phone after every change, so the flow can be
/// left and resumed at any point. The same controller (another instance,
/// [mediaEditControllerProvider]) changes the video and photos of a
/// listing already online: [startEdit] / [applyEdit].
class SellController extends Notifier<SellState> {
  SellController({this.prefKey = PrefKeys.sellDraft});

  /// Where the draft is kept on the phone.
  final String prefKey;

  static const _uuid = Uuid();
  static const _renderShare = 0.7;
  static const thumbSize = Size(270, 480);
  static const coverSize = Size(1080, 1920);

  Future<void>? _running;
  bool _again = false;

  SellMedia get _media => ref.read(sellMediaProvider);
  SellRepository get _repo => ref.read(sellRepositoryProvider);
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  SellState build() => SellState.empty;

  /// The draft left on this phone, if any (not loaded into the state).
  SellDraft? savedDraft() {
    final raw = _prefs.getString(prefKey);
    if (raw == null) return null;
    try {
      return SellDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Opens the saved draft, or a new one for [categoryId] (the saved one
  /// is thrown away when [fresh] or of another category).
  Future<void> start(String categoryId, {bool fresh = false}) async {
    final saved = savedDraft();
    if (saved != null && (fresh || saved.categoryId != categoryId)) await discard();
    var draft = (!fresh && saved?.categoryId == categoryId)
        ? saved!
        : SellDraft(id: _uuid.v4(), categoryId: categoryId, createdAt: DateTime.now());
    final steps = await _repo.captureSteps(categoryId);
    if (!ref.mounted) return;
    final slots = PhotoSlot.defaultsFor(categoryId);
    draft = draft.normalized(steps, slots);
    state = SellState(draft: draft, steps: steps, slots: slots);
    await _save(draft);
  }

  /// "Foto e video" of an online listing: its photos as they are online,
  /// its video kept until the steps are shot again. Resumes an edit of the
  /// same listing left on the phone. Throws when the listing is not the
  /// user's ([PublishFailure.notEditable]) or offline.
  Future<void> startEdit(String listingId) async {
    final saved = savedDraft();
    if (saved != null && !(saved.editing && saved.id == listingId)) await discard();
    var draft = saved != null && saved.editing && saved.id == listingId ? saved : null;
    final categoryId = draft?.categoryId;
    EditableMedia? media;
    if (draft == null) {
      media = await _repo.editableMedia(listingId);
      if (media == null) throw const PublishException(PublishFailure.notEditable);
    }
    final category = categoryId ?? media!.categoryId;
    final steps = await _repo.captureSteps(category);
    if (!ref.mounted) return;
    final slots = PhotoSlot.defaultsFor(category);
    if (draft == null) {
      final slotIds = {for (final s in slots) s.id};
      final used = <String>{};
      draft = SellDraft(
        id: listingId,
        categoryId: category,
        createdAt: DateTime.now(),
        editing: true,
        publishedCover: media!.coverPath,
        initialMediaIds: [for (final p in media.photos) p.id],
        photos: [
          for (final p in media.photos)
            Shot.remote(
              // One photo per slot; anything else is one of "Altre foto".
              stepId: p.step != null && slotIds.contains(p.step) && used.add(p.step!) ? p.step! : PhotoSlot.extra,
              mediaId: p.id,
              path: p.path,
            ),
        ],
      );
    }
    state = SellState(draft: draft, steps: steps, slots: slots);
    await _save(draft);
  }

  /// Editing: back to the video that is online (the new clips go).
  Future<void> keepPublishedVideo() async {
    final draft = state.draft;
    if (draft == null || !draft.editing || draft.shots.isEmpty) return;
    try {
      await _media.cancel(_renderTask(draft.id));
    } catch (_) {}
    final dir = await _media.draftDir(draft.id);
    final files = [for (final s in draft.shots.values) ...[s.file, s.thumb], draft.video, draft.cover];
    _set(draft.copyWith(shots: const {}, video: null, cover: null, renderedFrom: null, videoDurationMs: null));
    await _deleteFiles(dir, files);
    _restartIfRunning();
  }

  /// Editing: uploads what changed and puts it online
  /// (`update-listing-media`); the phone copy goes. Throws
  /// [PublishException].
  Future<void> applyEdit() async {
    final draft = state.draft;
    if (draft == null || !draft.editing) throw const PublishException(PublishFailure.other);
    if (!draft.readyIn(state.steps)) throw const PublishException(PublishFailure.incomplete);
    try {
      await prepareMedia();
    } catch (e) {
      if (kDebugMode) debugPrint('edit prepare: $e');
      throw const PublishException(PublishFailure.network);
    }

    final current = state.draft ?? draft;
    final carousel = current.carousel(state.slots);
    try {
      await _repo.applyMediaEdit(
        listingId: current.id,
        video: !current.keepsVideo,
        videoDurationMs: current.videoDurationMs,
        photos: [
          for (final (i, p) in carousel.indexed)
            p.isRemote ? {'media_id': p.mediaId!} : {'file': SellDraft.photoName(i, p)},
        ],
      );
    } on PublishException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('apply edit: $e');
      throw const PublishException(PublishFailure.network);
    }

    await _prefs.remove(prefKey);
    await _media.deleteDraftDir(current.id);
    if (!ref.mounted) return;
    state = SellState.empty;
    ref.invalidate(listingDetailProvider(current.id));
    ref.invalidate(feedControllerProvider);
    ref.invalidate(myListingsProvider);
  }

  /// Deletes the draft and its files (phone only; uploads left in the
  /// private drafts bucket are overwritten or cleaned by the next one).
  Future<void> discard() async {
    final saved = state.draft ?? savedDraft();
    _again = false;
    await _prefs.remove(prefKey);
    if (saved != null) {
      try {
        await _media.cancel(_renderTask(saved.id));
      } catch (_) {}
      await _media.deleteDraftDir(saved.id);
    }
    if (ref.mounted) state = SellState.empty;
  }

  Future<void> _save(SellDraft draft) =>
      _prefs.setString(prefKey, jsonEncode(draft.toJson()));

  void _set(SellDraft draft) {
    state = state.copyWith(draft: draft);
    unawaited(_save(draft));
  }

  Future<String> pathOf(String fileName) async {
    final draft = state.draft!;
    return '${(await _media.draftDir(draft.id)).path}/$fileName';
  }

  /// The clip for [stepId] (replaces the previous one). [tempPath] is the
  /// camera's file; it is moved into the draft folder.
  Future<void> addClip(String stepId, String tempPath) async {
    final draft = state.draft;
    if (draft == null) return;
    final dir = await _media.draftDir(draft.id);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = '$stepId-$stamp.mp4';
    await _moveFile(tempPath, '${dir.path}/$file');

    String? thumb = '$stepId-$stamp-thumb.jpg';
    try {
      await _media.thumbnail(video: '${dir.path}/$file', out: '${dir.path}/$thumb', size: thumbSize);
    } catch (e) {
      thumb = null; // the summary shows an icon instead
      if (kDebugMode) debugPrint('thumbnail: $e');
    }

    final current = state.draft ?? draft;
    final previous = current.shots[stepId];
    _set(current.copyWith(shots: {
      ...current.shots,
      stepId: Shot(stepId: stepId, kind: ShotKind.video, file: file, thumb: thumb, takenAt: DateTime.now()),
    }));
    if (previous != null) await _deleteFiles(dir, [previous.file, previous.thumb]);
    _restartIfRunning();
  }

  Future<void> removeShot(String stepId) async {
    final draft = state.draft;
    final shot = draft?.shots[stepId];
    if (draft == null || shot == null) return;
    _set(draft.copyWith(shots: {...draft.shots}..remove(stepId)));
    await _deleteFiles(await _media.draftDir(draft.id), [shot.file, shot.thumb]);
    _restartIfRunning();
  }

  /// A carousel photo for [slotId] (replaces the slot's previous one) or,
  /// with [PhotoSlot.extra], one more of "Altre foto" (false when they
  /// are already [SellDraft.maxExtras]). Camera files are moved into the
  /// draft folder, gallery files copied ([fromCamera]).
  Future<bool> addPhoto(String slotId, String path, {required bool fromCamera}) async {
    final draft = state.draft;
    if (draft == null) return false;
    final extra = slotId == PhotoSlot.extra;
    if (extra && draft.extraPhotos.length >= SellDraft.maxExtras) return false;
    final dir = await _media.draftDir(draft.id);
    final file = '$slotId-${DateTime.now().microsecondsSinceEpoch}.jpg';
    if (fromCamera) {
      await _moveFile(path, '${dir.path}/$file');
    } else {
      // Gallery files belong to the gallery: copy, never move.
      await File(path).copy('${dir.path}/$file');
    }
    if (!ref.mounted) return true;
    final current = state.draft ?? draft;
    final previous = extra ? null : current.photoFor(slotId);
    _set(current.copyWith(photos: [
      for (final p in current.photos)
        if (p != previous) p,
      Shot(stepId: slotId, kind: ShotKind.photo, file: file, takenAt: DateTime.now()),
    ]));
    if (previous != null) await _deleteFiles(dir, [previous.file]);
    _restartIfRunning();
    return true;
  }

  /// Several gallery photos into "Altre foto", up to [SellDraft.maxExtras].
  /// Returns how many were added.
  Future<int> addExtraPhotos(List<String> paths) async {
    var added = 0;
    for (final path in paths) {
      if (!await addPhoto(PhotoSlot.extra, path, fromCamera: false)) break;
      added++;
    }
    return added;
  }

  Future<void> removePhoto(String file) async {
    final draft = state.draft;
    if (draft == null || !draft.photos.any((s) => s.file == file)) return;
    _set(draft.copyWith(photos: [...draft.photos]..removeWhere((s) => s.file == file)));
    await _deleteFiles(await _media.draftDir(draft.id), [file]);
    _restartIfRunning();
  }

  void updateDetails(SellDetails details) {
    final draft = state.draft;
    if (draft != null) _set(draft.copyWith(details: details));
  }

  // ---- video + uploads ----------------------------------------------

  String _renderTask(String draftId) => 'sell-$draftId';

  /// A shot changed after "Crea il video": the video is made again.
  void _restartIfRunning() {
    if (_running != null) {
      _again = true;
    } else if (state.phase != MediaPhase.idle) {
      state = state.copyWith(phase: MediaPhase.idle, progress: 0);
      startMedia();
    }
  }

  /// "Crea il video": starts [prepareMedia] in the background; a failure
  /// shows in [SellState.phase] (and publish tries again).
  void startMedia() => unawaited(prepareMedia().catchError((_) {}));

  /// Makes the video and uploads everything. Safe to call again (does
  /// only what is missing); a second call while running waits for it.
  Future<void> prepareMedia() {
    if (_running != null) return _running!;
    final run = _prepare();
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  Future<void> _prepare() async {
    do {
      _again = false;
      try {
        await _renderIfNeeded();
        if (_again) continue;
        await _uploadMissing();
        if (_again) continue;
        if (ref.mounted) state = state.copyWith(phase: MediaPhase.ready, progress: 1);
      } catch (e) {
        if (kDebugMode) debugPrint('sell media: $e');
        if (_again) continue;
        if (ref.mounted) state = state.copyWith(phase: MediaPhase.failed);
        rethrow;
      }
    } while (_again && ref.mounted && state.draft != null);
  }

  Future<void> _renderIfNeeded() async {
    final draft = state.draft;
    if (draft == null || draft.videoUpToDate) return;
    final dir = await _media.draftDir(draft.id);
    final key = draft.mediaKey;
    final clips = [for (final s in draft.videosIn(state.steps)) '${dir.path}/${s.file}'];
    if (clips.isEmpty) throw StateError('No video shot');

    state = state.copyWith(phase: MediaPhase.rendering, progress: 0);
    final config = ref.read(appConfigProvider).value ?? AppConfig.empty;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final video = 'video-$stamp.mp4';
    final cover = 'cover-$stamp.jpg';

    final duration = await _media.renderVideo(
      taskId: _renderTask(draft.id),
      clips: clips,
      out: '${dir.path}/$video',
      bitrate: config.mediaValue('video_bitrate_kbps', 4500) * 1000,
      onProgress: (p) {
        if (ref.mounted && state.phase == MediaPhase.rendering) {
          state = state.copyWith(progress: p.clamp(0, 1) * _renderShare * 0.95);
        }
      },
    );
    await _media.thumbnail(video: '${dir.path}/$video', out: '${dir.path}/$cover', size: coverSize);
    if (!ref.mounted) return;

    final current = state.draft ?? draft;
    if (current.mediaKey != key) {
      // A step was retaken meanwhile: this video is already old.
      await _deleteFiles(dir, [video, cover]);
      _again = true;
      return;
    }
    final old = [current.video, current.cover];
    _set(current.copyWith(video: video, cover: cover, videoDurationMs: duration, renderedFrom: key));
    await _deleteFiles(dir, old);
    state = state.copyWith(progress: _renderShare);
  }

  /// What `listing-drafts/<user>/<draft>/` must hold: name -> (local file,
  /// content type, source key). See publish-listing for the names.
  Map<String, (String, String, String)> _wanted(SellDraft d) {
    final photos = d.carousel(state.slots);
    return {
      if (!d.keepsVideo) ...{
        'video.mp4': (d.video!, 'video/mp4', d.renderedFrom!),
        'cover.jpg': (d.cover!, 'image/jpeg', d.renderedFrom!),
      },
      // Photos already online stay where they are.
      for (var i = 0; i < photos.length; i++)
        if (!photos[i].isRemote)
          SellDraft.photoName(i, photos[i]):
            (photos[i].file, 'image/jpeg', photos[i].file),
    };
  }

  Future<void> _uploadMissing() async {
    final draft = state.draft;
    if (draft == null || !draft.videoUpToDate) return;
    final dir = await _media.draftDir(draft.id);
    final wanted = _wanted(draft);
    final todo = wanted.entries.where((e) => draft.uploaded[e.key] != e.value.$3).toList();
    final stale = draft.uploaded.keys.where((k) => !wanted.containsKey(k)).toList();

    state = state.copyWith(phase: MediaPhase.uploading, progress: _renderShare);
    // The video weighs most: it moves the bar the most.
    double weight(String name) => name == 'video.mp4' ? 6 : 1;
    final total = todo.fold<double>(0, (sum, e) => sum + weight(e.key));
    var done = 0.0;

    for (final e in todo) {
      final (file, type, source) = e.value;
      await _repo.upload(draftId: draft.id, file: File('${dir.path}/$file'), name: e.key, contentType: type);
      if (!ref.mounted) return;
      final current = state.draft ?? draft;
      _set(current.copyWith(uploaded: {...current.uploaded, e.key: source}));
      done += weight(e.key);
      state = state.copyWith(progress: _renderShare + (1 - _renderShare) * done / total);
      if (_again) return;
    }

    if (stale.isNotEmpty) {
      await _repo.removeUploads(draft.id, stale);
      if (!ref.mounted) return;
      final current = state.draft ?? draft;
      _set(current.copyWith(uploaded: {...current.uploaded}..removeWhere((k, _) => stale.contains(k))));
    }
  }

  // ---- publish --------------------------------------------------------

  /// Saves the listing row, waits for the media, then puts it online.
  /// Returns the listing id; the draft is gone from the phone afterwards.
  /// Throws [PublishException].
  Future<String> publish({
    required String? dealerId,
    String? newPhone,
    bool recordSellerAge = false,
  }) async {
    final draft = state.draft;
    if (draft == null) throw const PublishException(PublishFailure.other);
    if (!draft.details.isComplete) throw const PublishException(PublishFailure.incomplete);

    try {
      await _repo.saveListing(draft, dealerId: dealerId);
      if (newPhone != null) await _repo.saveSellerPhone(newPhone);
      if (recordSellerAge) await _repo.recordSellerAgeConsent();
      await prepareMedia();
    } on PublishException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('publish prepare: $e');
      throw const PublishException(PublishFailure.network);
    }

    final current = state.draft ?? draft;
    try {
      await _repo.publish(draftId: current.id, videoDurationMs: current.videoDurationMs);
    } on PublishException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('publish: $e');
      throw const PublishException(PublishFailure.network);
    }

    // Online: the phone copy is no longer needed.
    await _prefs.remove(prefKey);
    await _media.deleteDraftDir(current.id);
    if (!ref.mounted) return current.id;
    state = SellState.empty;
    ref.invalidate(feedControllerProvider); // the new listing shows up
    ref.invalidate(myListingsProvider); // and in "I miei annunci"
    return current.id;
  }

  // ---- files ----------------------------------------------------------

  static Future<void> _moveFile(String from, String to) async {
    final source = File(from);
    try {
      await source.rename(to);
    } on FileSystemException {
      // Another volume (camera cache): copy, then delete.
      await source.copy(to);
      await source.delete();
    }
  }

  static Future<void> _deleteFiles(Directory dir, List<String?> names) async {
    for (final name in names) {
      if (name == null) continue;
      final f = File('${dir.path}/$name');
      if (f.existsSync()) await f.delete();
    }
  }
}

final sellControllerProvider = NotifierProvider<SellController, SellState>(SellController.new);

/// "Foto e video" of a listing already online: its own draft, so a new
/// listing in progress is never touched.
final mediaEditControllerProvider = NotifierProvider<SellController, SellState>(
  () => SellController(prefKey: PrefKeys.mediaEditDraft),
);
