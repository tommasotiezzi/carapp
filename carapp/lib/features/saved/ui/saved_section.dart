import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../feed/ui/listing_card.dart';
import '../data/favorites_repository.dart';
import '../state/saved_controller.dart';

/// "Salvati" in the profile: two-column grid, newest first.
class SavedSection extends ConsumerWidget {
  const SavedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final saved = ref.watch(savedListingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(t.savedTitle, style: text.titleLarge)),
            if (saved.value?.isNotEmpty ?? false)
              Text('${saved.value!.length}', style: text.titleSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        saved.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.l),
            child: Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          error: (_, _) => Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref.invalidate(savedListingsProvider),
              child: Text(t.commonRetry),
            ),
          ),
          data: (items) => items.isEmpty
              ? Text(t.savedEmpty, style: text.bodyMedium)
              : ListingCardGrid(children: [for (final item in items) _SavedCard(item: item)]),
        ),
      ],
    );
  }
}

class _SavedCard extends ConsumerWidget {
  const _SavedCard({required this.item});

  final SavedListing item;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(savedControllerProvider.notifier)
          .setSaved(listingId: item.listingId, saved: false);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.savedError)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final drop = item.priceDropCents;

    return ListingCard(
      item: item.listing,
      unavailableLabel: t.savedUnavailable,
      topRight: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: t.savedRemove,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.bookmark, color: AppColors.primary, size: 20),
          onPressed: () => _remove(context, ref),
        ),
      ),
      badge: drop == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                t.savedPriceDrop(Formatters.price(drop)),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.successInk),
              ),
            ),
    );
  }
}
