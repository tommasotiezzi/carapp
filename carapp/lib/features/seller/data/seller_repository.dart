import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/geo/italian_capitals.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../feed/data/feed_repository.dart';

/// The header of a seller page: a dealer (public `dealers` row) or a
/// private seller (`public_profiles`, only what they chose to show).
class SellerProfile {
  const SellerProfile({
    required this.ref,
    this.name,
    this.city,
    this.province,
    this.verified = false,
    this.description,
    this.website,
    this.phone,
    this.whatsapp,
    this.hasPhone = false,
    this.hasWhatsapp = false,
    this.memberSince,
    this.avatarPath,
  });

  final SellerRef ref;

  /// Profile picture (`avatars` bucket): the dealer's or the user's.
  final String? avatarPath;

  /// null for a private seller without a display name.
  final String? name;
  final String? city;
  final String? province;

  /// Dealers: VAT number checked with VIES.
  final bool verified;
  final String? description;
  final String? website;

  /// null when hidden, or when the user is a guest (see [hasPhone]).
  final String? phone;
  final String? whatsapp;

  /// The seller shows a number, maybe only to signed-in users.
  final bool hasPhone;
  final bool hasWhatsapp;
  final DateTime? memberSince;

  bool get isDealer => ref.isDealer;

  /// "Milano (MI)"
  String? get place {
    final c = (city ?? '').trim().isNotEmpty ? city!.trim() : ItalianCapitals.byCode[province]?.name;
    if (c == null) return null;
    return province == null ? c : '$c ($province)';
  }

  factory SellerProfile.fromDealerRow(Map<String, dynamic> row) {
    String? text(String key) {
      final v = (row[key] as String?)?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    return SellerProfile(
      ref: SellerRef.dealer(row['id'] as String),
      name: text('display_name'),
      city: text('city'),
      province: text('province'),
      verified: row['vat_verified_at'] != null,
      description: text('description'),
      website: text('website'),
      phone: text('phone'),
      whatsapp: text('whatsapp'),
      hasPhone: text('phone') != null,
      hasWhatsapp: text('whatsapp') != null,
      memberSince: DateTime.tryParse((row['created_at'] as String?) ?? ''),
      avatarPath: text('logo_path'),
    );
  }

  factory SellerProfile.fromPublicProfileRow(Map<String, dynamic> row) => SellerProfile(
        ref: SellerRef.private(row['id'] as String),
        name: (row['display_name'] as String?)?.trim(),
        city: row['city'] as String?,
        province: row['province'] as String?,
        phone: row['phone'] as String?,
        whatsapp: row['whatsapp'] as String?,
        hasPhone: (row['has_phone'] as bool?) ?? false,
        hasWhatsapp: (row['has_whatsapp'] as bool?) ?? false,
        memberSince: DateTime.tryParse((row['member_since'] as String?) ?? ''),
        avatarPath: row['avatar_path'] as String?,
      );
}

class SellerRepository {
  SellerRepository(this._client);

  final SupabaseClient _client;

  static const _dealerColumns =
      'id, display_name, logo_path, city, province, phone, whatsapp, website, description, vat_verified_at, created_at';

  /// null when the seller does not exist or (private) has nothing online.
  Future<SellerProfile?> fetch(SellerRef ref) async {
    if (ref.isDealer) {
      final row = await _client.from('dealers').select(_dealerColumns).eq('id', ref.id).maybeSingle();
      return row == null ? null : SellerProfile.fromDealerRow(row);
    }
    final row = await _client.from('public_profiles').select().eq('id', ref.id).maybeSingle();
    return row == null ? null : SellerProfile.fromPublicProfileRow(row);
  }

  /// Active listings of the seller (head request, no rows).
  Future<int> activeCount(SellerRef ref) {
    var query = _client.from('listings').count(CountOption.exact).eq('status', 'active');
    query = ref.isDealer
        ? query.eq('dealer_id', ref.id)
        : query.eq('owner_id', ref.id).eq('seller_type', 'private');
    return query;
  }
}

final sellerRepositoryProvider = Provider<SellerRepository>(
  (ref) => SellerRepository(ref.watch(supabaseProvider)),
);
