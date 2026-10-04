import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import 'capture_step.dart';
import 'sell_draft.dart';

/// Why publishing (or saving changed media) stopped.
enum PublishFailure { incomplete, missingMedia, notDraft, notEditable, network, other }

/// A listing's media as they are online, to edit them.
class EditableMedia {
  const EditableMedia({required this.categoryId, this.coverPath, this.photos = const []});

  final String categoryId;
  final String? coverPath;

  /// Carousel order.
  final List<({String id, String path, String? step})> photos;
}

class PublishException implements Exception {
  const PublishException(this.failure);
  final PublishFailure failure;

  @override
  String toString() => 'PublishException($failure)';
}

/// The seller's contact data the form starts from.
class SellerProfile {
  const SellerProfile({this.phone, this.whatsappPublic = false, this.city, this.dealerId});

  final String? phone;
  final bool whatsappPublic;
  final String? city;

  /// Set when the user belongs to a dealer: the listing is the dealer's.
  final String? dealerId;
}

/// Server side of the sell flow: the draft row, the uploads to
/// `listing-drafts/<user>/<draft id>/`, and the `publish-listing` call.
class SellRepository {
  SellRepository(this._client);

  final SupabaseClient _client;

  static const draftsBucket = 'listing-drafts';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Selling needs a signed-in user');
    return id;
  }

  Future<List<CaptureStep>> captureSteps(String categoryId) async {
    try {
      final row = await _client
          .from('vehicle_categories')
          .select('capture_steps')
          .eq('id', categoryId)
          .maybeSingle();
      final steps = CaptureStep.listFromJson(row?['capture_steps']);
      if (steps.isNotEmpty) return steps;
    } catch (e) {
      if (kDebugMode) debugPrint('capture steps: $e');
    }
    return CaptureStep.defaultsFor(categoryId);
  }

  Future<SellerProfile> sellerProfile() async {
    final userId = _userId;
    final (profile, membership) = await (
      _client.from('profiles').select('phone, whatsapp_public, city').eq('id', userId).maybeSingle(),
      _client.from('dealer_members').select('dealer_id').eq('profile_id', userId).limit(1).maybeSingle(),
    ).wait;
    return SellerProfile(
      phone: profile?['phone'] as String?,
      whatsappPublic: (profile?['whatsapp_public'] as bool?) ?? false,
      city: profile?['city'] as String?,
      dealerId: membership?['dealer_id'] as String?,
    );
  }

  /// Insert or update the draft row (id = draft id). Status, media paths
  /// and dates are never sent: publish-listing sets them.
  Future<void> saveListing(SellDraft draft, {String? dealerId}) => _client.from('listings').upsert({
        'id': draft.id,
        'owner_id': _userId,
        'seller_type': dealerId == null ? 'private' : 'dealer',
        'dealer_id': dealerId,
        'category_id': draft.categoryId,
        ...draft.details.toListingRow(),
      });

  String _remotePath(String draftId, String name) => '$_userId/$draftId/$name';

  Future<void> upload({
    required String draftId,
    required File file,
    required String name,
    required String contentType,
  }) =>
      _client.storage.from(draftsBucket).upload(
            _remotePath(draftId, name),
            file,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

  Future<void> removeUploads(String draftId, List<String> names) async {
    if (names.isEmpty) return;
    await _client.storage.from(draftsBucket).remove([for (final n in names) _remotePath(draftId, n)]);
  }

  /// Private sellers: the number shown on WhatsApp lives in the profile.
  Future<void> saveSellerPhone(String phone) => _client
      .from('profiles')
      .update({'phone': phone.trim(), 'whatsapp_public': true})
      .eq('id', _userId);

  Future<bool> hasSellerAgeConsent() async {
    final row = await _client
        .from('current_consents')
        .select('granted')
        .eq('kind', 'seller_age')
        .maybeSingle();
    return (row?['granted'] as bool?) ?? false;
  }

  Future<void> recordSellerAgeConsent() => _client.from('user_consents').insert({
        'profile_id': _userId,
        'kind': 'seller_age',
        'granted': true,
        'platform': switch (defaultTargetPlatform) {
          TargetPlatform.iOS => 'ios',
          TargetPlatform.android => 'android',
          _ => 'web',
        },
      });

  /// The listing's category, cover and photos (RLS: own or dealer's
  /// listings, also sold). null when it is not the user's.
  Future<EditableMedia?> editableMedia(String listingId) async {
    final row = await _client
        .from('listings')
        .select('category_id, cover_path, media:listing_media(id, kind, storage_path, capture_step, sort_order)')
        .eq('id', listingId)
        .maybeSingle();
    if (row == null) return null;
    final media = ((row['media'] as List?) ?? const []).cast<Map<String, dynamic>>()
        .where((m) => m['kind'] == 'photo')
        .toList()
      ..sort((a, b) => ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));
    return EditableMedia(
      categoryId: row['category_id'] as String,
      coverPath: row['cover_path'] as String?,
      photos: [
        for (final m in media)
          (id: m['id'] as String, path: m['storage_path'] as String, step: m['capture_step'] as String?),
      ],
    );
  }

  /// Puts the changed media online (`update-listing-media`): [video] =
  /// a new video.mp4 + cover.jpg were uploaded; [photos] = the whole
  /// carousel, `{'media_id': ...}` (kept) or `{'file': ...}` (uploaded).
  Future<void> applyMediaEdit({
    required String listingId,
    required bool video,
    int? videoDurationMs,
    required List<Map<String, String>> photos,
  }) async {
    try {
      await _client.functions.invoke('update-listing-media', body: {
        'listing_id': listingId,
        'video': video,
        if (video) 'video_duration_ms': ?videoDurationMs,
        'photos': photos,
      });
    } on FunctionException catch (e) {
      final code = e.details is Map ? (e.details as Map)['error'] : null;
      throw PublishException(switch (code) {
        'missing_media' => PublishFailure.missingMedia,
        'not_editable' || 'not_found' => PublishFailure.notEditable,
        _ => PublishFailure.other,
      });
    }
  }

  Future<void> publish({required String draftId, int? videoDurationMs}) async {
    try {
      await _client.functions.invoke('publish-listing', body: {
        'listing_id': draftId,
        'video_duration_ms': ?videoDurationMs,
      });
    } on FunctionException catch (e) {
      final code = e.details is Map ? (e.details as Map)['error'] : null;
      throw PublishException(switch (code) {
        'incomplete' => PublishFailure.incomplete,
        'missing_media' => PublishFailure.missingMedia,
        'not_draft' => PublishFailure.notDraft,
        _ => PublishFailure.other,
      });
    }
  }
}

final sellRepositoryProvider = Provider<SellRepository>(
  (ref) => SellRepository(ref.watch(supabaseProvider)),
);
