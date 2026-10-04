import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

class InboxState {
  const InboxState({this.items = const [], this.hasMore = false, this.loadingMore = false});

  final List<ConversationSummary> items;
  final bool hasMore;
  final bool loadingMore;

  static const empty = InboxState();

  int get unreadCount => items.where((c) => c.unread).length;

  ConversationSummary? byId(String id) {
    for (final c in items) {
      if (c.id == id) return c;
    }
    return null;
  }

  ConversationSummary? forListing(String listingId) {
    for (final c in items) {
      if (c.isBuyer && c.listingId == listingId) return c;
    }
    return null;
  }

  InboxState copyWith({List<ConversationSummary>? items, bool? hasMore, bool? loadingMore}) =>
      InboxState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );

  /// Adds or replaces [rows] and keeps the newest activity first.
  InboxState upsert(Iterable<ConversationSummary> rows) {
    final byId = {for (final c in items) c.id: c};
    for (final r in rows) {
      byId[r.id] = r;
    }
    final sorted = byId.values.toList()..sort((a, b) => b.activityAt.compareTo(a.activityAt));
    return copyWith(items: sorted);
  }
}

/// The user's chats, kept live: the first page is loaded once per login,
/// then Realtime says which chat changed and only that row is fetched
/// again. Empty for guests. Kept alive: the tab badge reads it.
class InboxController extends AsyncNotifier<InboxState> {
  static const _coalesce = Duration(milliseconds: 300);

  /// How long the first load waits for Realtime before going ahead.
  static const subscribeTimeout = Duration(seconds: 3);

  final _changed = <String>{};
  Timer? _timer;
  bool _loaded = false;

  @override
  Future<InboxState> build() async {
    final userId = ref.watch(currentUserIdProvider);
    _loaded = false;
    _changed.clear();
    if (userId == null) return InboxState.empty;

    final repo = ref.read(chatRepositoryProvider);
    final subscribed = Completer<void>();
    final sub = repo.watchConversations().listen((id) {
      if (id == null && !subscribed.isCompleted) {
        subscribed.complete();
      } else {
        _onChange(id);
      }
    });
    ref.onDispose(() {
      sub.cancel();
      _timer?.cancel();
    });

    // Load once Realtime listens, so nothing falls between the two and
    // no second request is needed.
    await subscribed.future.timeout(subscribeTimeout, onTimeout: () {});
    final items = await repo.inbox();
    _loaded = true;
    return InboxState(items: items, hasMore: items.length == ChatRepository.inboxPageSize);
  }

  void _onChange(String? conversationId) {
    if (conversationId == null) {
      // Re-subscribed after a drop: changes may have been missed.
      if (_loaded) unawaited(_reloadFirstPage(replace: false));
      return;
    }
    _changed.add(conversationId);
    // A new message also moves the read marker: one fetch for both.
    _timer?.cancel();
    _timer = Timer(_coalesce, _fetchChanged);
  }

  Future<void> _fetchChanged() async {
    if (state.hasError) {
      _changed.clear();
      return;
    }
    if (state.value == null) {
      // First page still loading: try again once it is there.
      _timer = Timer(_coalesce, _fetchChanged);
      return;
    }
    final ids = _changed.toList();
    _changed.clear();
    final repo = ref.read(chatRepositoryProvider);
    try {
      final rows = await Future.wait(ids.map(repo.conversation));
      if (!ref.mounted) return;
      final current = state.value;
      if (current == null) return;
      state = AsyncData(current.upsert(rows.whereType<ConversationSummary>()));
    } catch (_) {
      // Offline: the catch-up on reconnect brings it back in step.
    }
  }

  /// [replace]: pull to refresh drops older pages; a catch-up merges.
  Future<void> _reloadFirstPage({required bool replace}) async {
    final repo = ref.read(chatRepositoryProvider);
    try {
      final rows = await repo.inbox();
      if (!ref.mounted) return;
      final current = state.value ?? InboxState.empty;
      state = AsyncData(replace
          ? InboxState(items: rows, hasMore: rows.length == ChatRepository.inboxPageSize)
          : current.upsert(rows));
    } catch (_) {
      if (replace) rethrow;
    }
  }

  Future<void> refresh() => _reloadFirstPage(replace: true);

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore || current.items.isEmpty) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final rows = await ref.read(chatRepositoryProvider).inbox(before: current.items.last.activityAt);
      if (!ref.mounted) return;
      final now = state.value ?? current;
      state = AsyncData(now
          .upsert(rows)
          .copyWith(loadingMore: false, hasMore: rows.length == ChatRepository.inboxPageSize));
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData((state.value ?? current).copyWith(loadingMore: false));
    }
  }

  /// The chat was opened: drop the unread dot at once (the database is
  /// updated by the chat screen).
  void markedRead(String conversationId) {
    final current = state.value;
    final row = current?.byId(conversationId);
    if (current == null || row == null || !row.unread) return;
    state = AsyncData(current.upsert([row.markedRead()]));
  }
}

final inboxProvider = AsyncNotifierProvider<InboxController, InboxState>(InboxController.new);

/// Chats with something new: the badge on the Inbox tab.
final unreadChatsProvider = Provider<int>(
  (ref) => ref.watch(inboxProvider.select((s) => s.value?.unreadCount ?? 0)),
);
