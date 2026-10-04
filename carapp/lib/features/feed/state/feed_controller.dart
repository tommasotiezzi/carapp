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
  });

  final List<FeedItem> items;
  final bool isLoadingMore;
  final bool hasMore;

  FeedState copyWith({
    List<FeedItem>? items,
    bool? isLoadingMore,
    bool? hasMore,
  }) =>
      FeedState(
        items: items ?? this.items,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
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
    return FeedState(items: items, hasMore: items.length == _pageSize);
  }

  /// Called when the user gets close to the end of what is loaded.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    if (current.items.isEmpty) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await ref.read(feedRepositoryProvider).fetchPage(
            before: current.items.last.publishedAt,
            pageSize: _pageSize,
            filters: ref.read(feedFiltersProvider),
          );
      state = AsyncData(current.copyWith(
        items: [...current.items, ...next],
        isLoadingMore: false,
        hasMore: next.length == _pageSize,
      ));
    } catch (_) {
      // Keep what we have; the next scroll retries.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final feedControllerProvider =
    AsyncNotifierProvider<FeedController, FeedState>(FeedController.new);
