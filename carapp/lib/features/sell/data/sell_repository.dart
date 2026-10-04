import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import 'capture_step.dart';
import 'sell_draft.dart';

/// Why publishing stopped.
enum PublishFailure { incomplete, missingMedia, notDraft, network, other }

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
