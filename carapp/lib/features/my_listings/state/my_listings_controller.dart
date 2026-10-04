import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../feed/state/feed_controller.dart';
import '../data/my_listings_repository.dart';

/// The user's listings, newest first; empty for guests. Loaded once per
/// login (profile, own listing page), then kept in step locally after
/// each action.
class MyListingsController extends AsyncNotifier<List<MyListing>> {
  @override
  Future<List<MyListing>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.read(myListingsRepositoryProvider).fetch();
  }

  MyListingsRepository get _repo => ref.read(myListingsRepositoryProvider);

  void _replace(MyListing updated) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([for (final l in list) l.id == updated.id ? updated : l]);
  }

  MyListing? _byId(String id) => state.value?.where((l) => l.id == id).firstOrNull;

  Future<void> refresh() async {
    final rows = await _repo.fetch();
    if (ref.mounted) state = AsyncData(rows);
  }

  /// Sold, removed, back online: the feed changes too.
  Future<void> setStatus(String listingId, String status) async {
    await _repo.setStatus(listingId, status);
    if (!ref.mounted) return;
    final l = _byId(listingId);
    if (status == 'removed') {
      state = AsyncData([for (final x in state.value ?? const <MyListing>[]) if (x.id != listingId) x]);
    } else if (l != null) {
      _replace(l.copyWith(status: status));
    }
    ref.invalidate(feedControllerProvider);
  }

  Future<void> updatePrice(String listingId, int priceCents) async {
    await _repo.updatePrice(listingId, priceCents);
    if (!ref.mounted) return;
    final l = _byId(listingId);
    if (l != null) _replace(l.copyWith(priceCents: priceCents));
    ref.invalidate(feedControllerProvider);
  }

  /// Returns how many people got it. Throws [OfferException].
  Future<int> offer(String listingId, int priceCents) async {
    final n = await _repo.offerToSavers(listingId, priceCents);
    if (!ref.mounted) return n;
    final l = _byId(listingId);
    if (l != null) _replace(l.copyWith(lastOfferAt: DateTime.now(), lastOfferPriceCents: priceCents));
    return n;
  }
}

final myListingsProvider =
    AsyncNotifierProvider<MyListingsController, List<MyListing>>(MyListingsController.new);

/// One of the user's listings (own listing page), null if not theirs.
final myListingProvider = Provider.family<MyListing?, String>(
  (ref, id) => ref.watch(myListingsProvider).value?.where((l) => l.id == id).firstOrNull,
);
