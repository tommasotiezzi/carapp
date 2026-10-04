import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'inbox_controller.dart';

class ChatState {
  const ChatState({
    required this.conversation,
    required this.userId,
    this.messages = const [],
    this.hasMore = false,
    this.loadingOlder = false,
  });

  final ConversationSummary conversation;
  final String userId;

  /// Newest first (the list is drawn bottom-up).
  final List<ChatMessage> messages;
  final bool hasMore;
  final bool loadingOlder;

  bool isMine(ChatMessage m) => conversation.isMine(m, userId);

  /// Newest message the server confirmed: the catch-up cursor.
  DateTime? get newestSent {
    for (final m in messages) {
      if (m.isSent) return m.createdAt;
    }
    return null;
  }

  DateTime? get oldestSent {
    for (final m in messages.reversed) {
      if (m.isSent) return m.createdAt;
    }
    return null;
  }

  ChatState copyWith({List<ChatMessage>? messages, bool? hasMore, bool? loadingOlder}) => ChatState(
        conversation: conversation,
        userId: userId,
        messages: messages ?? this.messages,
        hasMore: hasMore ?? this.hasMore,
        loadingOlder: loadingOlder ?? this.loadingOlder,
      );

  /// Adds server messages not already there, newest first. A server copy
  /// of a message still shown as "sending" replaces it.
  ChatState merge(Iterable<ChatMessage> incoming) {
    final list = [...messages];
    for (final m in incoming) {
      if (list.any((e) => e.id == m.id)) continue;
      final pending = list.indexWhere((e) =>
          e.status == MessageStatus.sending && e.senderId == m.senderId && e.body == m.body);
      if (pending >= 0) list.removeAt(pending);
      list.add(m);
    }
    list.sort(_newestFirst);
    return copyWith(messages: list);
  }

  static int _newestFirst(ChatMessage a, ChatMessage b) {
    // Unsent messages stay at the bottom, under everything received.
    if (a.isSent != b.isSent) return a.isSent ? 1 : -1;
    return b.createdAt.compareTo(a.createdAt);
  }
}

/// One open chat. Loads the latest messages, then receives new ones
/// through Realtime; sending is optimistic (the bubble shows at once,
/// "Non inviato" if the insert fails). null = chat not found.
class ChatController extends AsyncNotifier<ChatState?> {
  ChatController(this.conversationId);

  final String conversationId;

  static const _readThrottle = Duration(seconds: 2);
  static const _uuid = Uuid();

  bool _loaded = false;
  DateTime? _lastRead;
  Timer? _readTimer;

  @override
  Future<ChatState?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    _loaded = false;
    if (userId == null) return null;

    final repo = ref.read(chatRepositoryProvider);
    final subscribed = Completer<void>();
    final sub = repo.watchMessages(conversationId).listen((m) {
      if (m == null && !subscribed.isCompleted) {
        subscribed.complete();
      } else {
        _onRealtime(m);
      }
    });
    ref.onDispose(() {
      sub.cancel();
      _readTimer?.cancel();
    });

    // The Inbox row already has the header data: no request for it.
    final known = ref.read(inboxProvider).value?.byId(conversationId);
    final summaryRequest = known != null ? Future.value(known) : repo.conversation(conversationId);
    await subscribed.future.timeout(InboxController.subscribeTimeout, onTimeout: () {});
    final (summary, messages) = await (summaryRequest, repo.messages(conversationId)).wait;
    if (summary == null) return null;

    _loaded = true;
    _markRead();
    return ChatState(
      conversation: summary,
      userId: userId,
      messages: messages,
      hasMore: messages.length == ChatRepository.messagesPageSize,
    );
  }

  void _onRealtime(ChatMessage? message) {
    final current = state.value;
    if (!_loaded || current == null) return;
    if (message == null) {
      unawaited(_catchUp());
      return;
    }
    state = AsyncData(current.merge([message]));
    if (!current.isMine(message)) _markRead();
  }

  /// After Realtime reconnects: what was sent meanwhile.
  Future<void> _catchUp() async {
    final after = state.value?.newestSent;
    try {
      final missed = await ref.read(chatRepositoryProvider).messages(conversationId, after: after);
      if (!ref.mounted || missed.isEmpty) return;
      final current = state.value;
      if (current != null) state = AsyncData(current.merge(missed));
      if (missed.any((m) => current != null && !current.isMine(m))) _markRead();
    } catch (_) {
      // Still offline: the next reconnect tries again.
    }
  }

  /// At most one request every 2 s while messages keep arriving.
  void _markRead() {
    ref.read(inboxProvider.notifier).markedRead(conversationId);
    final now = DateTime.now();
    final last = _lastRead;
    if (last != null && now.difference(last) < _readThrottle) {
      _readTimer ??= Timer(_readThrottle - now.difference(last), () {
        _readTimer = null;
        if (ref.mounted) _markRead();
      });
      return;
    }
    _lastRead = now;
    unawaited(ref.read(chatRepositoryProvider).markRead(conversationId).catchError((_) {}));
  }

  Future<void> loadOlder() async {
    final current = state.value;
    final before = current?.oldestSent;
    if (current == null || before == null || !current.hasMore || current.loadingOlder) return;
    state = AsyncData(current.copyWith(loadingOlder: true));
    try {
      final older = await ref.read(chatRepositoryProvider).messages(conversationId, before: before);
      if (!ref.mounted) return;
      final now = state.value ?? current;
      state = AsyncData(now.merge(older).copyWith(
            loadingOlder: false,
            hasMore: older.length == ChatRepository.messagesPageSize,
          ));
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData((state.value ?? current).copyWith(loadingOlder: false));
    }
  }

  /// Shows the message at once and sends it. [body] must not be blank.
  Future<void> send(String body) async {
    final current = state.value;
    final text = body.trim();
    if (current == null || text.isEmpty) return;
    final local = ChatMessage(
      id: 'local-${_uuid.v4()}',
      senderId: current.userId,
      body: text,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    state = AsyncData(current.copyWith(messages: [local, ...current.messages]));
    await _deliver(local);
  }

  /// "Non inviato" tapped: sends the same text again.
  Future<void> retry(String localId) async {
    final current = state.value;
    final failed = current?.messages.where((m) => m.id == localId).firstOrNull;
    if (current == null || failed == null || failed.status != MessageStatus.failed) return;
    final again = failed.withStatus(MessageStatus.sending);
    state = AsyncData(current.copyWith(messages: _replace(current.messages, localId, again)));
    await _deliver(again);
  }

  void discard(String localId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      messages: current.messages.where((m) => m.id != localId).toList(),
    ));
  }

  Future<void> _deliver(ChatMessage local) async {
    try {
      final saved = await ref.read(chatRepositoryProvider).send(conversationId, local.body);
      if (!ref.mounted) return;
      final current = state.value;
      if (current == null) return;
      // Realtime may have delivered it already (merged into `local`).
      final rest = current.messages.where((m) => m.id != local.id);
      state = AsyncData(current.copyWith(messages: rest.toList()).merge([saved]));
    } catch (_) {
      if (!ref.mounted) return;
      final current = state.value;
      if (current == null || !current.messages.any((m) => m.id == local.id)) return;
      state = AsyncData(current.copyWith(
        messages: _replace(current.messages, local.id, local.withStatus(MessageStatus.failed)),
      ));
    }
  }

  static List<ChatMessage> _replace(List<ChatMessage> list, String id, ChatMessage replacement) =>
      [for (final m in list) m.id == id ? replacement : m];
}

final chatControllerProvider =
    AsyncNotifierProvider.autoDispose.family<ChatController, ChatState?, String>(ChatController.new);
