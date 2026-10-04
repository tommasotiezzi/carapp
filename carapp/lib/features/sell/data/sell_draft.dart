import 'capture_step.dart';

enum ShotKind { video, photo }

/// What was captured for one step. Files live in the draft folder on the
/// phone; only their names are stored.
class Shot {
  const Shot({
    required this.stepId,
    required this.kind,
    required this.file,
    this.thumb,
    this.takenAt,
    this.mediaId,
    this.remotePath,
  });

  /// A photo already online (`listing_media`), when editing a listing.
  /// Its [file] is a placeholder name ("remote-<id>"), nothing local.
  factory Shot.remote({required String stepId, required String mediaId, required String path}) =>
      Shot(stepId: stepId, kind: ShotKind.photo, file: 'remote-$mediaId', mediaId: mediaId, remotePath: path);

  final String stepId;
  final ShotKind kind;

  /// File name in the draft folder (clip .mp4 or photo .jpg).
  final String file;

  /// Set for a photo already online: its `listing_media` id and path.
  final String? mediaId;
  final String? remotePath;

  bool get isRemote => mediaId != null;

  /// Small preview .jpg for the summary (videos); photos show themselves.
  final String? thumb;
  final DateTime? takenAt;

  Map<String, dynamic> toJson() => {
        'step_id': stepId,
        'kind': kind.name,
        'file': file,
        'thumb': thumb,
        'taken_at': takenAt?.toIso8601String(),
        'media_id': ?mediaId,
        'remote_path': ?remotePath,
      };

  Shot copyWithStep(String id) => Shot(
        stepId: id,
        kind: kind,
        file: file,
        thumb: thumb,
        takenAt: takenAt,
        mediaId: mediaId,
        remotePath: remotePath,
      );

  factory Shot.fromJson(Map<String, dynamic> json) => Shot(
        stepId: json['step_id'] as String,
        kind: ShotKind.values.byName(json['kind'] as String),
        file: json['file'] as String,
        thumb: json['thumb'] as String?,
        takenAt: DateTime.tryParse((json['taken_at'] as String?) ?? ''),
        mediaId: json['media_id'] as String?,
        remotePath: json['remote_path'] as String?,
      );
}

/// The "Dati e prezzo" form. Same names as the `listings` columns.
class SellDetails {
  const SellDetails({
    this.makeId,
    this.modelId,
    this.version,
    this.year,
    this.mileageKm,
    this.priceCents,
    this.fuelType,
    this.transmission,
    this.powerKw,
    this.euroClass,
    this.ownersCount,
    this.color,
    this.hasServiceHistory,
    this.description,
    this.city,
    this.province,
    this.whatsapp = false,
    this.phone,
    this.attributes = const {},
  });

  final String? makeId;
  final String? modelId;
  final String? version;
  final int? year;
  final int? mileageKm;
  final int? priceCents;
  final String? fuelType;
  final String? transmission;
  final int? powerKw;
  final int? euroClass;
  final int? ownersCount;
  final String? color;
  final bool? hasServiceHistory;
  final String? description;
  final String? city;
  final String? province;
  final bool whatsapp;

  /// Private sellers: the number shown on WhatsApp (saved in the profile).
  final String? phone;

  /// Category fields (`listings.attributes`): body_type, novice_ok, ...
  final Map<String, Object?> attributes;

  static const empty = SellDetails();

  /// Fields the database requires before publishing (publish-listing).
  List<String> get missing => [
        if (makeId == null) 'make_id',
        if (modelId == null) 'model_id',
        if (year == null) 'year',
        if (mileageKm == null) 'mileage_km',
        if (priceCents == null) 'price_cents',
        if (fuelType == null) 'fuel_type',
        if ((city ?? '').trim().isEmpty) 'city',
        // The capital places the listing ("entro X km").
        if ((province ?? '').trim().isEmpty) 'province',
      ];

  bool get isComplete => missing.isEmpty;

  static const _unset = Object();

  SellDetails copyWith({
    Object? makeId = _unset,
    Object? modelId = _unset,
    Object? version = _unset,
    Object? year = _unset,
    Object? mileageKm = _unset,
    Object? priceCents = _unset,
    Object? fuelType = _unset,
    Object? transmission = _unset,
    Object? powerKw = _unset,
    Object? euroClass = _unset,
    Object? ownersCount = _unset,
    Object? color = _unset,
    Object? hasServiceHistory = _unset,
    Object? description = _unset,
    Object? city = _unset,
    Object? province = _unset,
    bool? whatsapp,
    Object? phone = _unset,
    Map<String, Object?>? attributes,
  }) {
    T? pick<T>(Object? value, T? current) => identical(value, _unset) ? current : value as T?;
    return SellDetails(
      makeId: pick(makeId, this.makeId),
      modelId: pick(modelId, this.modelId),
      version: pick(version, this.version),
      year: pick(year, this.year),
      mileageKm: pick(mileageKm, this.mileageKm),
      priceCents: pick(priceCents, this.priceCents),
      fuelType: pick(fuelType, this.fuelType),
      transmission: pick(transmission, this.transmission),
      powerKw: pick(powerKw, this.powerKw),
      euroClass: pick(euroClass, this.euroClass),
      ownersCount: pick(ownersCount, this.ownersCount),
      color: pick(color, this.color),
      hasServiceHistory: pick(hasServiceHistory, this.hasServiceHistory),
      description: pick(description, this.description),
      city: pick(city, this.city),
      province: pick(province, this.province),
      whatsapp: whatsapp ?? this.whatsapp,
      phone: pick(phone, this.phone),
      attributes: attributes ?? this.attributes,
    );
  }

  /// The listing row (insert or update). Never the fields only
  /// publish-listing sets (status, paths, dates).
  Map<String, dynamic> toListingRow() {
    String? text(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();
    return {
      'make_id': makeId,
      'model_id': modelId,
      'version': text(version),
      'year': year,
      'mileage_km': mileageKm,
      'price_cents': priceCents,
      'fuel_type': fuelType,
      'transmission': transmission,
      'power_kw': powerKw,
      'euro_class': euroClass,
      'owners_count': ownersCount,
      'color': text(color),
      'has_service_history': hasServiceHistory,
      'description': text(description),
      'city': text(city),
      'province': text(province)?.toUpperCase(),
      'whatsapp_enabled': whatsapp,
      'attributes': {
        for (final e in attributes.entries)
          if (e.value != null) e.key: e.value,
      },
    };
  }

  Map<String, dynamic> toJson() => {
        ...toListingRow(),
        'version': version,
        'color': color,
        'description': description,
        'city': city,
        'province': province,
        'phone': phone,
      };

  factory SellDetails.fromJson(Map<String, dynamic> json) {
    int? integer(String key) => (json[key] as num?)?.toInt();
    return SellDetails(
      makeId: json['make_id'] as String?,
      modelId: json['model_id'] as String?,
      version: json['version'] as String?,
      year: integer('year'),
      mileageKm: integer('mileage_km'),
      priceCents: integer('price_cents'),
      fuelType: json['fuel_type'] as String?,
      transmission: json['transmission'] as String?,
      powerKw: integer('power_kw'),
      euroClass: integer('euro_class'),
      ownersCount: integer('owners_count'),
      color: json['color'] as String?,
      hasServiceHistory: json['has_service_history'] as bool?,
      description: json['description'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      whatsapp: (json['whatsapp_enabled'] as bool?) ?? false,
      phone: json['phone'] as String?,
      attributes: Map<String, Object?>.from((json['attributes'] as Map?) ?? const {}),
    );
  }
}

/// A listing being created, kept on the phone until it is online: the
/// user can stop at any point and resume. Its [id] is also the id of the
/// listing row and the name of its folder in `listing-drafts`.
class SellDraft {
  const SellDraft({
    required this.id,
    required this.categoryId,
    required this.createdAt,
    this.shots = const {},
    this.photos = const [],
    this.details = SellDetails.empty,
    this.video,
    this.cover,
    this.videoDurationMs,
    this.renderedFrom,
    this.uploaded = const {},
    this.editing = false,
    this.publishedCover,
    this.initialMediaIds = const [],
  });

  final String id;
  final String categoryId; // 'car' | 'motorcycle'
  final DateTime createdAt;

  /// Video clips by step id (every step is a video: the video is never
  /// replaced by photos).
  final Map<String, Shot> shots;

  /// Carousel photos, all optional: one per [PhotoSlot] (stepId = slot
  /// id) plus up to [maxExtras] "Altre foto" (stepId = [PhotoSlot.extra]).
  final List<Shot> photos;

  static const maxExtras = 10;

  final SellDetails details;

  /// The edited video and its cover, in the draft folder (once made).
  final String? video;
  final String? cover;
  final int? videoDurationMs;

  /// [mediaKey] of the shots the video was made from: when they change
  /// (a step retaken), the video is made again.
  final String? renderedFrom;

  /// Remote file name -> [mediaKey] it was uploaded from.
  final Map<String, String> uploaded;

  /// "Foto e video" of a listing already online ([id] = the listing's id):
  /// the photos start as the online ones ([Shot.isRemote]) and the video
  /// stays unless the steps are shot again.
  final bool editing;

  /// Editing: the online cover (shown while the video is kept).
  final String? publishedCover;

  /// Editing: the online photos at the start, in order (to tell changes).
  final List<String> initialMediaIds;

  /// Editing without shooting the video again.
  bool get keepsVideo => editing && shots.isEmpty;

  /// Editing: something to save.
  bool get hasEdits =>
      shots.isNotEmpty ||
      photos.any((p) => !p.isRemote) ||
      !_sameList([for (final p in photos) p.mediaId!], initialMediaIds);

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Name of a carousel photo in the uploads folder (position [index] in
  /// the carousel, 0-based). See publish-listing / update-listing-media.
  static String photoName(int index, Shot photo) =>
      'photo-${(index + 1).toString().padLeft(2, '0')}-${photo.stepId}.jpg';

  /// What the video is made of: changes when a clip is added, retaken or
  /// removed (photos do not change the video).
  String get mediaKey => (shots.values
          .where((s) => s.kind == ShotKind.video)
          .map((s) => '${s.stepId}:${s.file}')
          .toList()
        ..sort())
      .join('|');

  List<Shot> videosIn(List<CaptureStep> steps) => [
        for (final step in steps)
          if (shots[step.id]?.kind == ShotKind.video) shots[step.id]!,
      ];

  Shot? photoFor(String slotId) => photos.where((p) => p.stepId == slotId).firstOrNull;

  List<Shot> get extraPhotos => [for (final p in photos) if (p.stepId == PhotoSlot.extra) p];

  /// The carousel: slot photos in slot order, then the other photos.
  List<Shot> carousel(List<PhotoSlot> slots) => [
        for (final slot in slots) ?photoFor(slot.id),
        ...extraPhotos,
      ];

  /// Required steps still without a clip.
  /// Editing and keeping the video: none.
  List<CaptureStep> missingIn(List<CaptureStep> steps) => keepsVideo
      ? const []
      : [for (final s in steps) if (s.required && shots[s.id]?.kind != ShotKind.video) s];

  /// Ready for "Crea il video": every required step done, at least one
  /// video (the feed shows the video). Editing: also when the video stays.
  bool readyIn(List<CaptureStep> steps) =>
      missingIn(steps).isEmpty && (keepsVideo || videosIn(steps).isNotEmpty);

  /// Steps renamed in the catalog (migration 15: 'front_three_quarter'
  /// became 'front').
  static const renamedSteps = {'front_three_quarter': 'front'};

  /// A draft started with an older app or catalog: a renamed step keeps
  /// its clip, and a step shot as a photo (steps were video or photo
  /// before) becomes a carousel photo, so that step is to film again.
  SellDraft normalized(List<CaptureStep> steps, List<PhotoSlot> slots) {
    final ids = {for (final s in steps) s.id};
    final slotIds = {for (final s in slots) s.id};
    final clips = <String, Shot>{};
    final moved = <Shot>[];
    for (final shot in shots.values) {
      var id = shot.stepId;
      final renamed = renamedSteps[id];
      if (renamed != null && !ids.contains(id) && ids.contains(renamed) && !shots.containsKey(renamed)) id = renamed;
      if (shot.kind == ShotKind.video) {
        clips[id] = id == shot.stepId ? shot : shot.copyWithStep(id);
      } else {
        final slot = slotIds.contains(id) && photoFor(id) == null && !moved.any((p) => p.stepId == id)
            ? id
            : PhotoSlot.extra;
        moved.add(shot.copyWithStep(slot));
      }
    }
    final changed = moved.isNotEmpty || clips.keys.toSet().difference(shots.keys.toSet()).isNotEmpty;
    if (!changed) return this;
    return copyWith(shots: clips, photos: [...photos, ...moved]);
  }

  bool get videoUpToDate => keepsVideo || (video != null && cover != null && renderedFrom == mediaKey);

  static const _unset = Object();

  SellDraft copyWith({
    Map<String, Shot>? shots,
    List<Shot>? photos,
    SellDetails? details,
    Object? video = _unset,
    Object? cover = _unset,
    Object? videoDurationMs = _unset,
    Object? renderedFrom = _unset,
    Map<String, String>? uploaded,
  }) =>
      SellDraft(
        id: id,
        categoryId: categoryId,
        createdAt: createdAt,
        shots: shots ?? this.shots,
        photos: photos ?? this.photos,
        details: details ?? this.details,
        video: identical(video, _unset) ? this.video : video as String?,
        cover: identical(cover, _unset) ? this.cover : cover as String?,
        videoDurationMs:
            identical(videoDurationMs, _unset) ? this.videoDurationMs : videoDurationMs as int?,
        renderedFrom: identical(renderedFrom, _unset) ? this.renderedFrom : renderedFrom as String?,
        uploaded: uploaded ?? this.uploaded,
        editing: editing,
        publishedCover: publishedCover,
        initialMediaIds: initialMediaIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'created_at': createdAt.toIso8601String(),
        'shots': [for (final s in shots.values) s.toJson()],
        'photos': [for (final s in photos) s.toJson()],
        'details': details.toJson(),
        'video': video,
        'cover': cover,
        'video_duration_ms': videoDurationMs,
        'rendered_from': renderedFrom,
        'uploaded': uploaded,
        if (editing) 'editing': true,
        'published_cover': ?publishedCover,
        if (initialMediaIds.isNotEmpty) 'initial_media_ids': initialMediaIds,
      };

  factory SellDraft.fromJson(Map<String, dynamic> json) {
    final shots = ((json['shots'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Shot.fromJson);
    return SellDraft(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      shots: {for (final s in shots) s.stepId: s},
      photos: ((json['photos'] as List?) ?? const []).cast<Map<String, dynamic>>().map(Shot.fromJson).toList(),
      details: SellDetails.fromJson(Map<String, dynamic>.from((json['details'] as Map?) ?? const {})),
      video: json['video'] as String?,
      cover: json['cover'] as String?,
      videoDurationMs: (json['video_duration_ms'] as num?)?.toInt(),
      renderedFrom: json['rendered_from'] as String?,
      uploaded: Map<String, String>.from((json['uploaded'] as Map?) ?? const {}),
      editing: (json['editing'] as bool?) ?? false,
      publishedCover: json['published_cover'] as String?,
      initialMediaIds: List<String>.from((json['initial_media_ids'] as List?) ?? const []),
    );
  }
}
