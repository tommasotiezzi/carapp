import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../feed/data/feed_filters.dart';
import '../../feed/data/feed_item.dart';
import '../../feed/data/feed_repository.dart';
import '../data/seller_repository.dart';

/// Header of a seller page. Reloads on login / logout: a private seller's
/// number is shown only to signed-in users.
final sellerProfileProvider = FutureProvider.autoDispose.family<SellerProfile?, SellerRef>((ref, seller) {
  ref.watch(currentUserIdProvider);
  return ref.watch(sellerRepositoryProvider).fetch(seller);
});

/// "12 annunci" (one head request).
final sellerListingCountProvider = FutureProvider.autoDispose.family<int, SellerRef>(
  (ref, seller) => ref.watch(sellerRepositoryProvider).activeCount(seller),
);

class SellerListingsState {
  const SellerListingsState({
    this.filters = FeedFilters.empty,
    this.items = const [],
    this.hasMore = false,
    this.loadingMore = false,
  });

  final FeedFilters filters;
  final List<FeedItem> items;
  final bool hasMore;
  final bool loadingMore;

  SellerListingsState copyWith({
    FeedFilters? filters,
    List<FeedItem>? items,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      SellerListingsState(
        filters: filters ?? this.filters,
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// The filters of one seller page (not the feed's), kept while it is open.
class SellerFiltersController extends Notifier<FeedFilters> {
  SellerFiltersController(this.seller);

  final SellerRef seller;

  @override
  FeedFilters build() => FeedFilters.empty;

  void set(FeedFilters filters) => state = filters;
}

final sellerFiltersProvider =
    NotifierProvider.autoDispose.family<SellerFiltersController, FeedFilters, SellerRef>(
  SellerFiltersController.new,
);

/// The listings grid of a seller page: same queries as the feed, scoped
/// to the seller, reloaded when its filters change.
class SellerListingsController extends AsyncNotifier<SellerListingsState> {
  SellerListingsController(this.seller);

  final SellerRef seller;
  static const pageSize = 20;

  @override
  Future<SellerListingsState> build() async {
    final filters = ref.watch(sellerFiltersProvider(seller));
    final items = await ref
        .read(feedRepositoryProvider)
        .fetchPage(pageSize: pageSize, filters: filters, seller: seller);
    return SellerListingsState(filters: filters, items: items, hasMore: items.length == pageSize);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore || current.items.isEmpty) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final more = await ref.read(feedRepositoryProvider).fetchPage(
            after: current.items.last,
            pageSize: pageSize,
            filters: current.filters,
            seller: seller,
          );
      if (!ref.mounted) return;
      final now = state.value;
      // Filters changed meanwhile: this page belongs to the old list.
      if (now == null || now.filters != current.filters) return;
      state = AsyncData(now.copyWith(
        items: [...now.items, ...more],
        hasMore: more.length == pageSize,
        loadingMore: false,
      ));
    } catch (_) {
      if (!ref.mounted) return;
      final now = state.value;
      if (now != null) state = AsyncData(now.copyWith(loadingMore: false));
    }
  }
}

final sellerListingsProvider =
    AsyncNotifierProvider.autoDispose.family<SellerListingsController, SellerListingsState, SellerRef>(
  SellerListingsController.new,
);
