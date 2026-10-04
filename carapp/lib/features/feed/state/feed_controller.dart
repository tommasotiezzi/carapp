import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/feed_item.dart';
import 'feed_filters_controller.dart';
import '../data/feed_repository.dart';

class FeedState {
  const FeedState({
    this.items = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
    this.generation = 0,
  });

  final List<FeedItem> items;
  final bool isLoadingMore;
  final bool hasMore;

  /// New for every first page (new filters, refresh); kept by loadMore.
  /// The pager uses it as its key, so a new list never reuses the
  /// previous list's video players (they are kept by position).
  final int generation;

  static int _nextGeneration = 0;

  FeedState copyWith({
    List<FeedItem>? items,
    bool? isLoadingMore,
    bool? hasMore,
  }) =>
      FeedState(
        items: items ?? this.items,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        generation: generation,
      );
}

class FeedController extends AsyncNotifier<FeedState> {
  int get _pageSize {
    final config = ref.read(appConfigProvider).value ?? AppConfig.empty;
    return config.feedValue('page_size', 10);
  }

  /// Rebuilt (first page reloaded) whenever the filters change.
  @override
  Future<FeedState> build() async {
    final filters = ref.watch(feedFiltersProvider);
    final items = await ref
        .read(feedRepositoryProvider)
        .fetchPage(pageSize: _pageSize, filters: filters);
    return FeedState(
      items: items,
      hasMore: items.length == _pageSize,
      generation: ++FeedState._nextGeneration,
    );
  }

  /// Called when the user gets close to the end of what is loaded.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    if (current.items.isEmpty) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await ref.read(feedRepositoryProvider).fetchPage(
            after: current.items.last,
            pageSize: _pageSize,
            filters: ref.read(feedFiltersProvider),
          );
      // Filters changed (or refresh) while loading: this page belongs to
      // the old list and must not be appended to the new one.
      if (!_stillShowing(current)) return;
      state = AsyncData(current.copyWith(
        items: [...current.items, ...next],
        isLoadingMore: false,
        hasMore: next.length == _pageSize,
      ));
    } catch (_) {
      // Keep what we have; the next scroll retries.
      if (_stillShowing(current)) state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  bool _stillShowing(FeedState list) =>
      ref.mounted && state.value?.generation == list.generation;

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final feedControllerProvider =
    AsyncNotifierProvider<FeedController, FeedState>(FeedController.new);
