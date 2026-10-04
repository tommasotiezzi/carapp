import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/listing_detail.dart';
import '../data/listing_repository.dart';

/// The listing, or null when it is gone. Dropped when the screen closes.
final listingDetailProvider = FutureProvider.autoDispose.family<ListingDetail?, String>(
  (ref, id) => ref.watch(listingRepositoryProvider).fetch(id),
);

/// Refetched on login / logout: the user's own pending questions
/// are visible only to them.
final listingQuestionsProvider =
    FutureProvider.autoDispose.family<List<ListingQuestion>, String>((ref, listingId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(listingRepositoryProvider).fetchQuestions(listingId);
});

final dealerReviewsProvider = FutureProvider.autoDispose.family<DealerReviews, String>(
  (ref, dealerId) => ref.watch(listingRepositoryProvider).fetchDealerReviews(dealerId),
);
