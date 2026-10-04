/// One row of the Inbox, from the `my_conversations()` function.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.listingId,
    required this.isBuyer,
    required this.buyerId,
    required this.activityAt,
    this.otherName,
    this.otherIsDealer = false,
    this.listingTitle,
    this.listingCoverPath,
    this.listingPriceCents,
    this.listingStatus = 'active',
    this.lastMessageBody,
    this.lastMessageMine = false,
    this.lastMessageAt,
    this.unread = false,
  });

  final String id;
  final String listingId;

  /// The user is the buyer (else the seller, or a member of the dealer).
  final bool isBuyer;
  final String buyerId;

  /// Dealer name, or the other user's display name (null if not set).
  final String? otherName;
  final bool otherIsDealer;
  final String? listingTitle;
  final String? listingCoverPath;
  final int? listingPriceCents;
  final String listingStatus; // `listing_status`
  final String? lastMessageBody;
  final bool lastMessageMine;
  final DateTime? lastMessageAt;

  /// Last message time, or creation time: the Inbox order and page cursor.
  final DateTime activityAt;
  final bool unread;

  bool get listingAvailable => listingStatus == 'active';

  /// On the seller side every message not sent by the buyer is "ours"
  /// (a colleague of the same dealer included).
  bool isMine(ChatMessage m, String userId) =>
      m.senderId == userId || (!isBuyer && m.senderId != buyerId);

  ConversationSummary markedRead() => ConversationSummary(
        id: id,
        listingId: listingId,
        isBuyer: isBuyer,
        buyerId: buyerId,
        activityAt: activityAt,
        otherName: otherName,
        otherIsDealer: otherIsDealer,
        listingTitle: listingTitle,
        listingCoverPath: listingCoverPath,
        listingPriceCents: listingPriceCents,
        listingStatus: listingStatus,
        lastMessageBody: lastMessageBody,
        lastMessageMine: lastMessageMine,
        lastMessageAt: lastMessageAt,
      );

  factory ConversationSummary.fromRow(Map<String, dynamic> row) => ConversationSummary(
        id: row['id'] as String,
        listingId: row['listing_id'] as String,
        isBuyer: row['is_buyer'] as bool,
        buyerId: row['buyer_id'] as String,
        otherName: row['other_name'] as String?,
        otherIsDealer: (row['other_is_dealer'] as bool?) ?? false,
        listingTitle: row['listing_title'] as String?,
        listingCoverPath: row['listing_cover_path'] as String?,
        listingPriceCents: (row['listing_price_cents'] as num?)?.toInt(),
        listingStatus: (row['listing_status'] as String?) ?? 'active',
        lastMessageBody: row['last_message_body'] as String?,
        lastMessageMine: (row['last_message_mine'] as bool?) ?? false,
        lastMessageAt: _time(row['last_message_at']),
        activityAt: _time(row['activity_at'])!,
        unread: (row['unread'] as bool?) ?? false,
      );
}

enum MessageStatus { sent, sending, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.status = MessageStatus.sent,
  });

  /// Server id, or a local id while [status] is not `sent`.
  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final MessageStatus status;

  bool get isSent => status == MessageStatus.sent;

  ChatMessage withStatus(MessageStatus status) =>
      ChatMessage(id: id, senderId: senderId, body: body, createdAt: createdAt, status: status);

  static const selectColumns = 'id, sender_id, body, created_at';

  /// Also parses Realtime payloads (same column names).
  factory ChatMessage.fromRow(Map<String, dynamic> row) => ChatMessage(
        id: row['id'] as String,
        senderId: row['sender_id'] as String,
        body: row['body'] as String,
        createdAt: _time(row['created_at'])!,
      );
}

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
