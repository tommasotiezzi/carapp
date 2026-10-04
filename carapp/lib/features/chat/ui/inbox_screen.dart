import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/ui/login_sheet.dart';
import '../data/chat_models.dart';
import '../state/inbox_controller.dart';
import 'chat_widgets.dart';

/// The Inbox tab: every chat of the user, as buyer and as seller, newest
/// activity first, kept live by Realtime.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final signedIn = ref.watch(currentUserIdProvider) != null;
    final inbox = ref.watch(inboxProvider);

    Widget body;
    if (!signedIn) {
      body = _InboxMessage(
        icon: Icons.chat_bubble_outline,
        title: t.inboxGuestTitle,
        body: t.inboxGuestBody,
        actionLabel: t.profileLogin,
        onAction: () => showLoginSheet(context),
      );
    } else if (inbox.hasError && inbox.value == null) {
      body = _InboxMessage(
        icon: Icons.wifi_off_outlined,
        title: t.errorTitle,
        body: t.errorBody,
        actionLabel: t.commonRetry,
        onAction: () => ref.invalidate(inboxProvider),
      );
    } else if (inbox.value == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (inbox.value!.items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => ref.read(inboxProvider.notifier).refresh(),
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: box.maxHeight,
              child: _InboxMessage(
                icon: Icons.chat_bubble_outline,
                title: t.inboxEmptyTitle,
                body: t.inboxEmptyBody,
                actionLabel: t.inboxExplore,
                onAction: () => context.go(AppRoutes.feed),
              ),
            ),
          ),
        ),
      );
    } else {
      final state = inbox.value!;
      final archivedRow = state.archivedCount > 0 ? 1 : 0;
      body = RefreshIndicator(
        onRefresh: () => ref.read(inboxProvider.notifier).refresh(),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: archivedRow + state.items.length + (state.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 84),
          itemBuilder: (context, index) {
            if (archivedRow == 1 && index == 0) {
              return ListTile(
                key: const ValueKey('archived-row'),
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                leading: const SizedBox(width: 56, child: Icon(Icons.archive_outlined, color: AppColors.inkSecondary)),
                title: Text(t.inboxArchived(state.archivedCount)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.archivedChats),
              );
            }
            final i = index - archivedRow;
            if (i == state.items.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(inboxProvider.notifier).loadMore());
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.l),
                child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final c = state.items[i];
            return Dismissible(
              key: ValueKey('chat-${c.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: AppColors.inkSecondary,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.archive_outlined, color: Colors.white),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      t.inboxArchive,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              onDismissed: (_) => _archive(context, ref, c),
              child: _ConversationTile(conversation: c, onTap: () => context.push(AppRoutes.chatPath(c.id))),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(t.inboxTitle)),
      body: body,
    );
  }
}

/// Archives at once; the snackbar offers "Annulla".
Future<void> _archive(BuildContext context, WidgetRef ref, ConversationSummary c) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(inboxProvider.notifier);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(t.inboxArchivedDone),
        action: SnackBarAction(
          label: t.commonUndo,
          onPressed: () => unawaited(controller.unarchive(c).catchError((_) {})),
        ),
      ),
    );
  try {
    await controller.archive(c.id);
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.inboxArchiveError)));
  }
}

/// `/chats/archived`: the archived chats; tap opens one, swipe brings it
/// back to the Inbox. A new message brings a chat back by itself.
class ArchivedChatsScreen extends ConsumerWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final chats = ref.watch(archivedChatsProvider);

    Future<void> restore(ConversationSummary c) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(inboxProvider.notifier).unarchive(c);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.inboxRestored)));
      } catch (_) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.inboxArchiveError)));
      }
      ref.invalidate(archivedChatsProvider);
    }

    final list = chats.value;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(t.inboxArchivedTitle)),
      body: list == null
          ? (chats.hasError
                ? _InboxMessage(
                    icon: Icons.wifi_off_outlined,
                    title: t.errorTitle,
                    body: t.errorBody,
                    actionLabel: t.commonRetry,
                    onAction: () => ref.invalidate(archivedChatsProvider),
                  )
                : const Center(child: CircularProgressIndicator()))
          : list.isEmpty
          ? Center(child: Text(t.inboxArchivedEmpty, style: Theme.of(context).textTheme.bodyLarge))
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 84),
              itemBuilder: (context, i) {
                final c = list[i];
                return Dismissible(
                  key: ValueKey('archived-${c.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppColors.primary,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.unarchive_outlined, color: Colors.white),
                        const SizedBox(width: AppSpacing.s),
                        Text(
                          t.inboxRestore,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (_) => restore(c),
                  child: _ConversationTile(conversation: c, onTap: () => context.push(AppRoutes.chatPath(c.id))),
                );
              },
            ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final ConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final c = conversation;
    final statusLabel = listingStatusLabel(c.listingStatus, t);
    final preview = c.lastMessageBody == null
        ? ''
        : c.lastMessageMine
        ? t.inboxYou(c.lastMessageBody!)
        : c.lastMessageBody!;
    final offer = c.lastMessageIsOffer && !c.lastMessageMine;
    final weight = c.unread ? FontWeight.w700 : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListingThumb(path: c.listingCoverPath),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherNameOf(c, t),
                          style: text.titleSmall?.copyWith(fontWeight: weight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Text(
                        Formatters.chatListTime(c.activityAt, yesterday: t.chatYesterday),
                        style: text.labelSmall?.copyWith(
                          color: c.unread ? AppColors.primary : AppColors.inkMuted,
                          fontWeight: weight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          [
                            c.listingTitle,
                            Formatters.price(c.listingPriceCents),
                          ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                          style: text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!c.isBuyer) ...[const SizedBox(width: AppSpacing.xs), ChatTag(t.inboxYourListing)],
                      if (statusLabel != null) ...[const SizedBox(width: AppSpacing.xs), ChatTag(statusLabel)],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      if (offer) ...[
                        const Icon(Icons.local_offer_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          preview,
                          style: text.bodyMedium?.copyWith(
                            color: c.unread ? AppColors.ink : AppColors.inkSecondary,
                            fontWeight: weight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (c.unread)
                        Container(
                          key: const ValueKey('unread-dot'),
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(left: AppSpacing.s),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.inkMuted),
            const SizedBox(height: AppSpacing.l),
            Text(title, style: text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s),
            Text(body, style: text.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
