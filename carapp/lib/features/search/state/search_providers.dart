import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../feed/data/feed_filters.dart';
import '../../feed/data/feed_repository.dart';
import '../../feed/state/feed_controller.dart';
import '../../feed/state/feed_filters_controller.dart';
import '../data/saved_search.dart';

/// Filters being edited on the Search screen. Starts from the feed's
/// filters and follows them when they change (pills, saved search),
/// so the two screens never disagree for long.
class SearchDraftController extends Notifier<FeedFilters> {
  @override
  FeedFilters build() => ref.watch(feedFiltersProvider);

  void update(FeedFilters filters) => state = filters;
}

final searchDraftProvider =
    NotifierProvider<SearchDraftController, FeedFilters>(SearchDraftController.new);

/// Results grid of the Search screen, for the current draft.
/// Waits a moment after each change so tapping several pills
/// sends one request, not one per tap.
class SearchResultsController extends AsyncNotifier<FeedState> {
  static const pageSize = 20;
  static const debounce = Duration(milliseconds: 350);

  @override
  Future<FeedState> build() async {
    final filters = ref.watch(searchDraftProvider);
    await Future<void>.delayed(debounce);
    // Superseded by a newer edit: that build will fetch, this one must not.
    if (!ref.mounted || ref.read(searchDraftProvider) != filters) return const FeedState();
    final items = await ref
        .read(feedRepositoryProvider)
        .fetchPage(pageSize: pageSize, filters: filters);
    return FeedState(items: items, hasMore: items.length == pageSize);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore || current.items.isEmpty) {
      return;
    }
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await ref.read(feedRepositoryProvider).fetchPage(
            before: current.items.last.publishedAt,
            pageSize: pageSize,
            filters: ref.read(searchDraftProvider),
          );
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(
        items: [...current.items, ...next],
        isLoadingMore: false,
        hasMore: next.length == pageSize,
      ));
    } catch (_) {
      if (ref.mounted) state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final searchResultsProvider =
    AsyncNotifierProvider<SearchResultsController, FeedState>(SearchResultsController.new);

/// The user's saved searches; empty for guests, reloaded on login/logout.
class SavedSearchesController extends AsyncNotifier<List<SavedSearch>> {
  @override
  Future<List<SavedSearch>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.read(savedSearchRepositoryProvider).fetchAll();
  }

  SavedSearchRepository get _repo => ref.read(savedSearchRepositoryProvider);

  Future<void> create({
    required String name,
    required FeedFilters filters,
    required bool notify,
  }) async {
    final created = await _repo.create(name: name, filters: filters, notify: notify);
    final list = [...await future, created]..sort((a, b) => a.name.compareTo(b.name));
    state = AsyncData(list);
  }

  /// Optimistic; rolls back and rethrows if the write fails.
  Future<void> setNotify(String id, bool notify) =>
      _optimistic([for (final s in state.value ?? const <SavedSearch>[]) s.id == id ? s.copyWith(notify: notify) : s],
          () => _repo.setNotify(id, notify));

  Future<void> delete(String id) => _optimistic(
        [...?state.value?.where((s) => s.id != id)],
        () => _repo.delete(id),
      );

  Future<void> _optimistic(List<SavedSearch> next, Future<void> Function() write) async {
    final before = state.value ?? const <SavedSearch>[];
    state = AsyncData(next);
    try {
      await write();
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}

final savedSearchesProvider =
    AsyncNotifierProvider<SavedSearchesController, List<SavedSearch>>(SavedSearchesController.new);
