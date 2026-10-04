import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

class InboxState {
  const InboxState({
    this.items = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.archivedCount = 0,
  });

  final List<ConversationSummary> items;
  final bool hasMore;
  final bool loadingMore;

  /// Chats the user archived ("Archiviate (3)").
  final int archivedCount;

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

  InboxState copyWith({
    List<ConversationSummary>? items,
    bool? hasMore,
    bool? loadingMore,
    int? archivedCount,
  }) =>
      InboxState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        archivedCount: archivedCount ?? this.archivedCount,
      );

  /// Adds or replaces [rows] and keeps the newest activity first.
  /// Archived rows leave the list.
  InboxState upsert(Iterable<ConversationSummary> rows) {
    final byId = {for (final c in items) c.id: c};
    for (final r in rows) {
      if (r.archived) {
        byId.remove(r.id);
      } else {
        byId[r.id] = r;
      }
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
    final (items, archived) = await (repo.inbox(), repo.archivedCount()).wait;
    _loaded = true;
    return InboxState(
      items: items,
      hasMore: items.length == ChatRepository.inboxPageSize,
      archivedCount: archived,
    );
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
      final rows = (await Future.wait(ids.map(repo.conversation))).whereType<ConversationSummary>().toList();
      if (!ref.mounted) return;
      final current = state.value;
      if (current == null) return;
      // A chat came back from the archive (new message) or went into it
      // from another phone: the count changed.
      final moved = rows.any((r) => r.archived == (current.byId(r.id) != null));
      final archived = moved ? await repo.archivedCount() : current.archivedCount;
      if (!ref.mounted) return;
      state = AsyncData((state.value ?? current).upsert(rows).copyWith(archivedCount: archived));
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

  /// Swipe "Archivia": out of the list at once, back if it fails.
  Future<void> archive(String conversationId) async {
    final current = state.value;
    final row = current?.byId(conversationId);
    if (current == null || row == null) return;
    state = AsyncData(current.copyWith(
      items: [for (final c in current.items) if (c.id != conversationId) c],
      archivedCount: current.archivedCount + 1,
    ));
    try {
      await ref.read(chatRepositoryProvider).archive(conversationId, archived: true);
    } catch (_) {
      if (!ref.mounted) return;
      final now = state.value ?? current;
      state = AsyncData(now.upsert([row]).copyWith(archivedCount: now.archivedCount - 1));
      rethrow;
    }
  }

  /// "Annulla" after archiving, or "Ripristina" in the archived list.
  Future<void> unarchive(ConversationSummary row) async {
    await ref.read(chatRepositoryProvider).archive(row.id, archived: false);
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.upsert([row.withArchived(false)]).copyWith(
      archivedCount: (current.archivedCount - 1).clamp(0, 1 << 30),
    ));
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

/// The archived chats (first page), for "Archiviate".
final archivedChatsProvider = FutureProvider.autoDispose<List<ConversationSummary>>(
  (ref) => ref.read(chatRepositoryProvider).inbox(archived: true),
);

/// Chats with something new: the badge on the Inbox tab.
final unreadChatsProvider = Provider<int>(
  (ref) => ref.watch(inboxProvider.select((s) => s.value?.unreadCount ?? 0)),
);
