import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/ui/login_sheet.dart';
import '../data/listing_detail.dart';
import '../data/listing_repository.dart';
import '../state/listing_providers.dart';
import 'listing_sections.dart';

/// Public Q&A of the listing plus the user's own pending questions.
class ListingQuestions extends ConsumerWidget {
  const ListingQuestions({super.key, required this.listing});

  final ListingDetail listing;

  Future<void> _ask(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    if (ref.read(currentUserProvider) == null) {
      final ok = await showLoginSheet(context, title: t.qaLoginTitle, subtitle: t.qaLoginSubtitle);
      if (!ok || !context.mounted) return;
    }
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AskSheet(listingId: listing.id),
    );
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.qaSent)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final questions = ref.watch(listingQuestionsProvider(listing.id));
    final isOwner = ref.watch(currentUserIdProvider) == listing.ownerId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListingSectionTitle(t.qaTitle),
        ...questions.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Center(
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          ],
          error: (_, _) => [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => ref.invalidate(listingQuestionsProvider(listing.id)),
                child: Text(t.commonRetry),
              ),
            ),
          ],
          data: (items) => items.isEmpty
              ? [Text(t.qaEmpty, style: text.bodyMedium)]
              : [
                  for (final q in items) ...[
                    _QuestionTile(question: q),
                    const SizedBox(height: AppSpacing.s),
                  ],
                ],
        ),
        if (!isOwner) ...[
          const SizedBox(height: AppSpacing.m),
          OutlinedButton.icon(
            onPressed: () => _ask(context, ref),
            icon: const Icon(Icons.help_outline, size: 20),
            label: Text(t.qaAsk),
          ),
        ],
      ],
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.question});

  final ListingQuestion question;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question.question, style: text.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          if (question.isAnswered)
            Text(question.answer!, style: text.bodyMedium)
          else
            Text(
              t.qaPending,
              style: text.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}

class _AskSheet extends ConsumerStatefulWidget {
  const _AskSheet({required this.listingId});

  final String listingId;

  @override
  ConsumerState<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends ConsumerState<_AskSheet> {
  static const _maxLength = 500; // listing_questions.question check
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = AppLocalizations.of(context);
    if (_ctrl.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(listingRepositoryProvider)
          .askQuestion(listingId: widget.listingId, question: _ctrl.text);
      ref.invalidate(listingQuestionsProvider(widget.listingId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = t.qaError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.qaYourQuestion, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.s),
          Text(t.qaNote, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.l),
          TextField(
            controller: _ctrl,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: _maxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: t.qaHint),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.m),
          FilledButton(
            onPressed: _busy || _ctrl.text.trim().isEmpty ? null : _send,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(t.qaSend),
          ),
        ],
      ),
    );
  }
}
