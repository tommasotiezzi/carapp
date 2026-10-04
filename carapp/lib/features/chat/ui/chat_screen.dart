import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../listing/data/listing_detail.dart';
import '../../listing/state/listing_providers.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import '../state/chat_controller.dart';
import 'chat_widgets.dart';

/// `/chat/:id` (an existing chat) and `/chat/new/:listingId` (no chat
/// yet: the first message creates it, then the same screen goes on as
/// that chat).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.conversationId, this.listingId})
    : assert(conversationId != null || listingId != null);

  final String? conversationId;
  final String? listingId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  late String? _conversationId = widget.conversationId;

  /// The first message while `start_conversation` runs.
  ChatMessage? _starting;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _show(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  void _send() {
    final body = _input.text.trim();
    final id = _conversationId;
    // While the first message creates the chat, wait for it.
    if (body.isEmpty || (id == null && _starting != null)) return;
    _input.clear();
    if (id != null) {
      ref.read(chatControllerProvider(id).notifier).send(body);
    } else {
      _start(body);
    }
  }

  Future<void> _start(String body) async {
    final t = AppLocalizations.of(context);
    final repo = ref.read(chatRepositoryProvider);
    setState(
      () => _starting = ChatMessage(
        id: 'local-first',
        senderId: ref.read(currentUserIdProvider) ?? '',
        body: body,
        createdAt: DateTime.now(),
        status: MessageStatus.sending,
      ),
    );
    try {
      final id = await repo.startConversation(listingId: widget.listingId!, body: body);
      if (!mounted) return;
      setState(() => _conversationId = id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = null);
      if (_input.text.isEmpty) _input.text = body;
      _show(switch (contactFailureOf(e)) {
        ContactFailure.listingUnavailable => t.contactListingUnavailable,
        ContactFailure.ownListing => t.contactOwnListing,
        ContactFailure.other => t.chatSendError,
      });
    }
  }

  void _useQuickReply(String text) {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = _conversationId;
    return id != null
        ? _ConversationBody(
            conversationId: id,
            input: _input,
            onSend: _send,
            // Shown while the new chat loads, so the bubble never blinks.
            placeholder: _starting,
          )
        : _NewChatBody(
            listingId: widget.listingId!,
            input: _input,
            onSend: _send,
            starting: _starting,
            onQuickReply: _useQuickReply,
          );
  }
}

// ---------------------------------------------------------------------
// Existing chat
// ---------------------------------------------------------------------

class _ConversationBody extends ConsumerWidget {
  const _ConversationBody({required this.conversationId, required this.input, required this.onSend, this.placeholder});

  final String conversationId;
  final TextEditingController input;
  final VoidCallback onSend;
  final ChatMessage? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final chat = ref.watch(chatControllerProvider(conversationId));
    final value = chat.value;

    if (chat.hasError && value == null) {
      return _ChatMessageScaffold(
        title: t.errorTitle,
        body: t.errorBody,
        actionLabel: t.commonRetry,
        onAction: () => ref.invalidate(chatControllerProvider(conversationId)),
      );
    }
    if (!chat.isLoading && value == null) {
      return _ChatMessageScaffold(title: t.chatNotFoundTitle, body: t.chatNotFoundBody);
    }

    final c = value?.conversation;
    return _ChatScaffold(
      name: c == null ? '' : otherNameOf(c, t),
      header: c == null
          ? null
          : _ListingStrip(
              listingId: c.listingId,
              title: c.listingTitle,
              priceCents: c.listingPriceCents,
              coverPath: c.listingCoverPath,
              status: c.listingStatus,
              yours: !c.isBuyer,
            ),
      input: input,
      onSend: onSend,
      body: value == null
          ? (placeholder == null
                ? const Center(child: CircularProgressIndicator())
                : _MessageList(messages: [placeholder!], isMine: (_) => true))
          : _MessageList(
              messages: value.messages,
              isMine: value.isMine,
              hasMore: value.hasMore,
              onLoadOlder: () => ref.read(chatControllerProvider(conversationId).notifier).loadOlder(),
              onFailedTap: (m) => _failedActions(context, ref, m),
            ),
    );
  }

  Future<void> _failedActions(BuildContext context, WidgetRef ref, ChatMessage m) async {
    final t = AppLocalizations.of(context);
    final controller = ref.read(chatControllerProvider(conversationId).notifier);
    final retry = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(t.commonRetry),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text(t.chatDelete, style: const TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (retry == true) {
      await controller.retry(m.id);
    } else if (retry == false) {
      controller.discard(m.id);
    }
  }
}

// ---------------------------------------------------------------------
// No chat yet
// ---------------------------------------------------------------------

class _NewChatBody extends ConsumerWidget {
  const _NewChatBody({
    required this.listingId,
    required this.input,
    required this.onSend,
    required this.onQuickReply,
    this.starting,
  });

  final String listingId;
  final TextEditingController input;
  final VoidCallback onSend;
  final ValueChanged<String> onQuickReply;
  final ChatMessage? starting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final listing = ref.watch(listingDetailProvider(listingId));

    return listing.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _ChatMessageScaffold(
        title: t.errorTitle,
        body: t.errorBody,
        actionLabel: t.commonRetry,
        onAction: () => ref.invalidate(listingDetailProvider(listingId)),
      ),
      data: (l) => l == null
          ? _ChatMessageScaffold(title: t.chatNotFoundTitle, body: t.contactListingUnavailable)
          : _newChat(context, t, l),
    );
  }

  Widget _newChat(BuildContext context, AppLocalizations t, ListingDetail l) {
    final name = l.dealer?.displayName ?? t.chatPrivateSeller;
    final quick = [t.chatQuickAvailable, t.chatQuickVisit, t.chatQuickPrice, t.chatQuickTradeIn];

    return _ChatScaffold(
      name: name,
      header: _ListingStrip(
        listingId: l.id,
        title: l.title,
        priceCents: l.priceCents,
        coverPath: l.coverPath,
        status: 'active',
      ),
      input: input,
      onSend: onSend,
      aboveInput: starting != null
          ? null
          : SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                itemCount: quick.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
                itemBuilder: (_, i) => ActionChip(label: Text(quick[i]), onPressed: () => onQuickReply(quick[i])),
              ),
            ),
      body: starting != null ? _MessageList(messages: [starting!], isMine: (_) => true) : _NewChatIntro(name: name),
    );
  }
}

class _NewChatIntro extends StatelessWidget {
  const _NewChatIntro({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        const Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.primary),
        const SizedBox(height: AppSpacing.l),
        Text(t.chatNewTitle(name), style: text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s),
        Text(t.chatNewBody, style: text.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xxl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(AppRadius.s)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 20, color: AppColors.inkSecondary),
              const SizedBox(width: AppSpacing.s),
              Expanded(child: Text(t.chatSafetyTip, style: text.bodySmall)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------

void _back(BuildContext context) => context.canPop() ? context.pop() : context.go(AppRoutes.inbox);

class _ChatScaffold extends StatelessWidget {
  const _ChatScaffold({
    required this.name,
    required this.body,
    required this.input,
    required this.onSend,
    this.header,
    this.aboveInput,
  });

  final String name;
  final Widget? header;
  final Widget body;
  final Widget? aboveInput;
  final TextEditingController input;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          ?header,
          Expanded(child: body),
          if (aboveInput != null) ...[aboveInput!, const SizedBox(height: AppSpacing.xs)],
          _Composer(controller: input, onSend: onSend),
        ],
      ),
    );
  }
}

/// The listing the chat is about; tap opens it while it is on sale.
class _ListingStrip extends StatelessWidget {
  const _ListingStrip({
    required this.listingId,
    required this.title,
    required this.priceCents,
    required this.coverPath,
    required this.status,
    this.yours = false,
  });

  final String listingId;
  final String? title;
  final int? priceCents;
  final String? coverPath;
  final String status;
  final bool yours;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final statusLabel = listingStatusLabel(status, t);

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: statusLabel != null ? null : () => context.push(AppRoutes.listingPath(listingId)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s, AppSpacing.page, AppSpacing.s),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              ListingThumb(path: coverPath, size: 44),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title ?? '', style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(Formatters.price(priceCents), style: text.bodySmall),
                        if (yours) ...[const SizedBox(width: AppSpacing.s), ChatTag(t.inboxYourListing)],
                        if (statusLabel != null) ...[const SizedBox(width: AppSpacing.s), ChatTag(statusLabel)],
                      ],
                    ),
                  ],
                ),
              ),
              if (statusLabel == null) const Icon(Icons.chevron_right, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.isMine,
    this.hasMore = false,
    this.onLoadOlder,
    this.onFailedTap,
  });

  /// Newest first.
  final List<ChatMessage> messages;
  final bool Function(ChatMessage) isMine;
  final bool hasMore;
  final VoidCallback? onLoadOlder;
  final ValueChanged<ChatMessage>? onFailedTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.m, AppSpacing.m, AppSpacing.s),
      itemCount: messages.length + (hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == messages.length) {
          // The top of the list came into view: fetch the older page.
          WidgetsBinding.instance.addPostFrameCallback((_) => onLoadOlder?.call());
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.l),
            child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final m = messages[i];
        final older = i + 1 < messages.length ? messages[i + 1] : null;
        final newer = i > 0 ? messages[i - 1] : null;
        final mine = isMine(m);
        final newDay = older == null || !Formatters.sameDay(older.createdAt, m.createdAt);
        // Consecutive messages from the same side sit closer together.
        final lastOfGroup = newer == null || isMine(newer) != mine;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newDay && !(hasMore && older == null)) _DaySeparator(m.createdAt),
            _Bubble(message: m, mine: mine, spaced: lastOfGroup, onFailedTap: onFailedTap),
          ],
        );
      },
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator(this.day);

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    final label = Formatters.sameDay(day, now)
        ? t.chatToday
        : Formatters.sameDay(day, now.subtract(const Duration(days: 1)))
        ? t.chatYesterday
        : Formatters.date(day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Center(child: ChatTag(label)),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.spaced, this.onFailedTap});

  final ChatMessage message;
  final bool mine;
  final bool spaced;
  final ValueChanged<ChatMessage>? onFailedTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final failed = message.status == MessageStatus.failed;
    final sending = message.status == MessageStatus.sending;
    final width = MediaQuery.sizeOf(context).width;

    final status = switch (message.status) {
      MessageStatus.sent => Formatters.time(message.createdAt),
      MessageStatus.sending => t.chatSending,
      MessageStatus.failed => t.chatFailed,
    };

    final bubble = message.isOffer
        ? _OfferCard(message: message, mine: mine, maxWidth: width * 0.75)
        : Container(
            constraints: BoxConstraints(maxWidth: width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
            decoration: BoxDecoration(
              color: mine ? AppColors.primary : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: Text(message.body, style: text.bodyLarge?.copyWith(color: mine ? Colors.white : AppColors.ink)),
          );

    return Padding(
      padding: EdgeInsets.only(bottom: spaced ? AppSpacing.m : 3),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: failed ? () => onFailedTap?.call(message) : null,
            child: Opacity(opacity: sending || failed ? 0.6 : 1, child: bubble),
          ),
          if (spaced || !message.isSent)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: GestureDetector(
                onTap: failed ? () => onFailedTap?.call(message) : null,
                child: Text(
                  status,
                  style: text.labelSmall?.copyWith(color: failed ? AppColors.danger : AppColors.inkMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An offer to the people who saved the listing: the reserved price,
/// the listing's price struck through, and (buyer side) an invitation to
/// answer.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.message, required this.mine, required this.maxWidth});

  final ChatMessage message;
  final bool mine;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('offer-card'),
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_offer_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  mine ? t.offerCardSeller : t.offerCardBuyer,
                  style: text.labelMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.s,
            children: [
              Text(Formatters.price(message.offerPriceCents), style: text.headlineSmall),
              Text(
                Formatters.price(message.offerListPriceCents),
                style: text.bodyMedium?.copyWith(color: AppColors.inkMuted, decoration: TextDecoration.lineThrough),
              ),
            ],
          ),
          if (!mine) ...[const SizedBox(height: AppSpacing.xs), Text(t.offerCardAnswer, style: text.bodySmall)],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s, AppSpacing.s, AppSpacing.s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(hintText: t.chatInputHint, counterText: '', isDense: true),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, _) => IconButton.filled(
                  tooltip: t.chatSend,
                  onPressed: value.text.trim().isEmpty ? null : onSend,
                  icon: const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessageScaffold extends StatelessWidget {
  const _ChatMessageScaffold({required this.title, required this.body, this.actionLabel, this.onAction});

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: text.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.s),
              Text(body, style: text.bodyLarge, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: AppSpacing.xl),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
