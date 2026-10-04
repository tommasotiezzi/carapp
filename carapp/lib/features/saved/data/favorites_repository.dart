import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../feed/data/feed_item.dart';

/// One row of the user's "Salvati".
class SavedListing {
  const SavedListing({
    required this.listingId,
    required this.priceCentsAtSave,
    this.listing,
  });

  final String listingId;
  final int? priceCentsAtSave;

  /// null when the listing is no longer visible (sold, expired, removed):
  /// RLS hides it, the favorite row stays.
  final FeedItem? listing;

  bool get isAvailable => listing != null;

  /// Cents the price went down since the user saved it, null if it did not.
  int? get priceDropCents {
    final before = priceCentsAtSave;
    final now = listing?.priceCents;
    if (before == null || now == null || now >= before) return null;
    return before - now;
  }

  factory SavedListing.fromRow(Map<String, dynamic> row) {
    final listing = row['listing'] as Map<String, dynamic>?;
    return SavedListing(
      listingId: row['listing_id'] as String,
      priceCentsAtSave: (row['price_cents_at_save'] as num?)?.toInt(),
      listing: listing == null ? null : FeedItem.fromRow(listing),
    );
  }
}

/// The `favorites` table. RLS limits every query to the signed-in user.
class FavoritesRepository {
  FavoritesRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Favorites need a signed-in user');
    return id;
  }

  /// Only the ids: one light query, used to draw the Save buttons.
  Future<Set<String>> fetchIds() async {
    final rows = await _client.from('favorites').select('listing_id');
    return {for (final r in rows) r['listing_id'] as String};
  }

  /// Newest first, with the listing data for the "Salvati" grid.
  Future<List<SavedListing>> fetchAll() async {
    final rows = await _client
        .from('favorites')
        .select('listing_id, price_cents_at_save, listing:listings(${FeedItem.selectColumns})')
        .order('created_at', ascending: false);
    return rows.map(SavedListing.fromRow).toList();
  }

  /// Idempotent: saving twice keeps the first price_cents_at_save,
  /// which is what price-drop alerts compare against.
  Future<void> save({required String listingId, required int? priceCents}) =>
      _client.from('favorites').upsert(
        {
          'profile_id': _userId,
          'listing_id': listingId,
          'price_cents_at_save': priceCents,
        },
        onConflict: 'profile_id,listing_id',
        ignoreDuplicates: true,
      );

  Future<void> unsave(String listingId) => _client
      .from('favorites')
      .delete()
      .eq('profile_id', _userId)
      .eq('listing_id', listingId);
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(supabaseProvider)),
);
