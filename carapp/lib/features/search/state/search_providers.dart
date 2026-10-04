import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../feed/data/feed_filters.dart';
import '../data/saved_search.dart';

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
    if (!ref.mounted) return;
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
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }
}

final savedSearchesProvider =
    AsyncNotifierProvider<SavedSearchesController, List<SavedSearch>>(SavedSearchesController.new);
