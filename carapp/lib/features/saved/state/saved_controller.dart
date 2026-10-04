import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/event_tracker.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../feed/data/feed_item.dart';
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
  /// [item] lets the "Salvati" grid add the card without reloading.
  Future<void> setSaved({
    required String listingId,
    required bool saved,
    int? priceCents,
    FeedItem? item,
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
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
    // Logged out while saving: the ids were reloaded, nothing to update.
    if (!ref.mounted) return;

    ref.read(eventTrackerProvider).track(
          saved ? AnalyticsEvent.save : AnalyticsEvent.unsave,
          listingId: listingId,
        );
    _updateSalvati(listingId: listingId, saved: saved, priceCents: priceCents, item: item);
  }

  /// Keeps the "Salvati" grid in step locally: no request per tap.
  /// Only reloads when a card has to be added and its data is unknown.
  void _updateSalvati({
    required String listingId,
    required bool saved,
    int? priceCents,
    FeedItem? item,
  }) {
    if (!ref.exists(savedListingsProvider)) return; // loads fresh when opened
    final list = ref.read(savedListingsProvider.notifier);
    if (!saved) {
      list.removed(listingId);
    } else if (item != null) {
      list.added(SavedListing(listingId: listingId, priceCentsAtSave: priceCents, listing: item));
    } else {
      ref.invalidate(savedListingsProvider);
    }
  }
}

final savedControllerProvider =
    AsyncNotifierProvider<SavedController, Set<String>>(SavedController.new);

/// true when [listingId] is saved (false while loading or for guests).
/// Auto-disposed: one per listing on screen, not one per listing ever seen.
final isSavedProvider = Provider.autoDispose.family<bool, String>(
  (ref, listingId) =>
      ref.watch(savedControllerProvider.select((s) => s.value?.contains(listingId) ?? false)),
);

/// Full rows for the "Salvati" grid in the profile, newest first.
/// Loaded once, then kept in step by [SavedController].
class SavedListingsController extends AsyncNotifier<List<SavedListing>> {
  @override
  Future<List<SavedListing>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.read(favoritesRepositoryProvider).fetchAll();
  }

  void added(SavedListing row) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([row, ...current.where((r) => r.listingId != row.listingId)]);
  }

  void removed(String listingId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((r) => r.listingId != listingId).toList());
  }
}

final savedListingsProvider =
    AsyncNotifierProvider<SavedListingsController, List<SavedListing>>(SavedListingsController.new);
