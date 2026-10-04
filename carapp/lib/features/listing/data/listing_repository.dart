import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import 'listing_detail.dart';

/// Reads one listing with its photos, seller, questions and reviews.
class ListingRepository {
  ListingRepository(this._client);

  final SupabaseClient _client;

  /// null when the listing does not exist or is no longer visible
  /// (sold, expired, removed: RLS hides it from everyone but the seller).
  Future<ListingDetail?> fetch(String id) async {
    final row = await _client
        .from('listings')
        .select(ListingDetail.selectColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ListingDetail.fromRow(row);
  }

  /// Newest first. Public answered questions + the user's own.
  Future<List<ListingQuestion>> fetchQuestions(String listingId) async {
    final rows = await _client
        .from('listing_questions')
        .select(ListingQuestion.selectColumns)
        .eq('listing_id', listingId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(ListingQuestion.fromRow).toList();
  }

  Future<void> askQuestion({required String listingId, required String question}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('askQuestion needs a signed-in user');
    await _client.from('listing_questions').insert({
      'listing_id': listingId,
      'asker_id': userId,
      'question': question.trim(),
    });
  }

  /// Average over the latest 200 reviews (no server-side aggregates yet)
  /// and the 3 most recent ones with a text.
  Future<DealerReviews> fetchDealerReviews(String dealerId) async {
    final rows = await _client
        .from('reviews')
        .select('rating, body, created_at')
        .eq('dealer_id', dealerId)
        .order('created_at', ascending: false)
        .limit(200);
    if (rows.isEmpty) return DealerReviews.empty;

    final reviews = rows.map(DealerReview.fromRow).toList();
    final total = reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return DealerReviews(
      count: reviews.length,
      average: total / reviews.length,
      latest: reviews.where((r) => (r.body ?? '').trim().isNotEmpty).take(3).toList(),
    );
  }
}

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => ListingRepository(ref.watch(supabaseProvider)),
);
