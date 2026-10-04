import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import 'chat_models.dart';

/// Why "Contatta" or WhatsApp could not go through.
enum ContactFailure { listingUnavailable, ownListing, other }

/// Maps the errors raised by `start_conversation()`.
ContactFailure contactFailureOf(Object error) {
  if (error is PostgrestException) {
    if (error.message.contains('listing_unavailable')) return ContactFailure.listingUnavailable;
    if (error.message.contains('own_listing')) return ContactFailure.ownListing;
  }
  return ContactFailure.other;
}

/// Chats: reads go through RLS (messages) or `my_conversations()`
/// (names and listing info), writes through the functions of migration
/// 11 except follow-up messages, which are a plain insert.
class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;
  var _channels = 0;

  static const inboxPageSize = 30;
  static const messagesPageSize = 40;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Chat needs a signed-in user');
    return id;
  }

  /// Newest activity first. [before] = the last row's `activityAt`.
  /// [archived]: the archived chats instead of the Inbox.
  Future<List<ConversationSummary>> inbox({DateTime? before, bool archived = false}) async {
    final rows = await _client.rpc<List<dynamic>>('my_conversations', params: {
      'p_before': before?.toUtc().toIso8601String(),
      'p_limit': inboxPageSize,
      'p_archived': archived,
    });
    return rows.cast<Map<String, dynamic>>().map(ConversationSummary.fromRow).toList();
  }

  /// Archive (or bring back) a chat for the user's side. A new message
  /// brings it back by itself.
  Future<void> archive(String conversationId, {required bool archived}) => _client.rpc<void>(
        'archive_conversation',
        params: {'p_conversation_id': conversationId, 'p_archived': archived},
      );

  Future<int> archivedCount() async =>
      ((await _client.rpc<Object?>('archived_conversations_count')) as num?)?.toInt() ?? 0;

  /// null when the chat does not exist or is not the user's.
  Future<ConversationSummary?> conversation(String id) async {
    final rows = await _client
        .rpc<List<dynamic>>('my_conversations', params: {'p_conversation_id': id});
    return rows.isEmpty ? null : ConversationSummary.fromRow(rows.first as Map<String, dynamic>);
  }

  /// The user's chat about [listingId] as buyer, if any.
  Future<String?> conversationIdForListing(String listingId) async {
    final row = await _client
        .from('conversations')
        .select('id')
        .eq('listing_id', listingId)
        .eq('buyer_id', _userId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  /// Newest first. [before]: older page; [after]: what arrived since
  /// (catch-up after Realtime reconnects).
  Future<List<ChatMessage>> messages(
    String conversationId, {
    DateTime? before,
    DateTime? after,
  }) async {
    var query = _client
        .from('messages')
        .select(ChatMessage.selectColumns)
        .eq('conversation_id', conversationId);
    if (before != null) query = query.lt('created_at', before.toUtc().toIso8601String());
    if (after != null) query = query.gt('created_at', after.toUtc().toIso8601String());
    final rows = await query.order('created_at', ascending: false).limit(messagesPageSize);
    return rows.map(ChatMessage.fromRow).toList();
  }

  Future<ChatMessage> send(String conversationId, String body) async {
    final row = await _client
        .from('messages')
        .insert({'conversation_id': conversationId, 'sender_id': _userId, 'body': body})
        .select(ChatMessage.selectColumns)
        .single();
    return ChatMessage.fromRow(row);
  }

  /// First message about a listing: creates the chat (or reuses it).
  /// Returns the conversation id. Errors: see [contactFailureOf].
  Future<String> startConversation({required String listingId, required String body}) async {
    final id = await _client.rpc<String>('start_conversation', params: {
      'p_listing_id': listingId,
      'p_body': body,
    });
    return id;
  }

  Future<void> markRead(String conversationId) =>
      _client.rpc<void>('mark_conversation_read', params: {'p_conversation_id': conversationId});

  /// The seller's WhatsApp number, null if they have none to show.
  Future<String?> sellerWhatsapp(String listingId) =>
      _client.rpc<String?>('seller_whatsapp', params: {'p_listing_id': listingId});

  /// New messages of one chat. Emits null each time the channel is
  /// (re)subscribed: messages sent meanwhile must be fetched.
  Stream<ChatMessage?> watchMessages(String conversationId) => _watch(
        topic: 'messages:$conversationId',
        event: PostgresChangeEvent.insert,
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        map: ChatMessage.fromRow,
      );

  /// Ids of the user's chats that were created or changed (new message,
  /// read marker). RLS sends only the user's own. null = (re)subscribed.
  Stream<String?> watchConversations() => _watch(
        topic: 'conversations',
        event: PostgresChangeEvent.all,
        table: 'conversations',
        map: (row) => row['id'] as String?,
      );

  Stream<T?> _watch<T>({
    required String topic,
    required PostgresChangeEvent event,
    required String table,
    required T? Function(Map<String, dynamic> row) map,
    PostgresChangeFilter? filter,
  }) {
    RealtimeChannel? channel;
    late final StreamController<T?> out;
    out = StreamController<T?>(
      onListen: () {
        // Unique topic: two screens on the same chat get two channels.
        channel = _client
            .channel('$topic:${_channels++}')
            .onPostgresChanges(
              event: event,
              schema: 'public',
              table: table,
              filter: filter,
              callback: (payload) {
                if (out.isClosed || payload.newRecord.isEmpty) return;
                final value = map(payload.newRecord);
                if (value != null) out.add(value);
              },
            )
            .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed && !out.isClosed) out.add(null);
        });
      },
      onCancel: () {
        final c = channel;
        channel = null;
        if (c != null) unawaited(_client.removeChannel(c));
      },
    );
    return out.stream;
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(supabaseProvider)),
);
