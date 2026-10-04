import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/event_tracker.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/favorites_repository.dart';

/// Ids of the listings the user saved. Empty for guests; reloaded on
/// login / logout. Changes are optimistic: the button flips at once and
/// flips back if the write fails.
class SavedController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const {};
    return ref.read(favoritesRepositoryProvider).fetchIds();
  }

  /// Saves or removes [listingId]. Needs a signed-in user.
  /// Throws if the write fails (state is already rolled back).
  Future<void> setSaved({
    required String listingId,
    required bool saved,
    int? priceCents,
  }) async {
    final before = await future;
    if (before.contains(listingId) == saved) return;

    state = AsyncData(saved ? {...before, listingId} : ({...before}..remove(listingId)));
    final repo = ref.read(favoritesRepositoryProvider);
    try {
      if (saved) {
        await repo.save(listingId: listingId, priceCents: priceCents);
      } else {
        await repo.unsave(listingId);
      }
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }

    ref.read(eventTrackerProvider).track(
          saved ? AnalyticsEvent.save : AnalyticsEvent.unsave,
          listingId: listingId,
        );
    ref.invalidate(savedListingsProvider);
  }
}

final savedControllerProvider =
    AsyncNotifierProvider<SavedController, Set<String>>(SavedController.new);

/// true when [listingId] is saved (false while loading or for guests).
final isSavedProvider = Provider.family<bool, String>(
  (ref, listingId) =>
      ref.watch(savedControllerProvider.select((s) => s.value?.contains(listingId) ?? false)),
);

/// Full rows for the "Salvati" grid in the profile.
final savedListingsProvider = FutureProvider<List<SavedListing>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.read(favoritesRepositoryProvider).fetchAll();
});
