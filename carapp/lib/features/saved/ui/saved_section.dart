import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/media_url.dart';
import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - AppSpacing.m) / 2;
                    return Wrap(
                      spacing: AppSpacing.m,
                      runSpacing: AppSpacing.l,
                      children: [
                        for (final item in items)
                          SizedBox(width: width, child: _SavedCard(item: item)),
                      ],
                    );
                  },
                ),
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
    final text = Theme.of(context).textTheme;
    final l = item.listing;
    final cover = l == null ? null : MediaUrl.resolve(ref.read(supabaseProvider), l.coverPath);
    final drop = item.priceDropCents;

    final image = AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.placeholder),
            if (cover != null)
              CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            if (l == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  child: Text(t.savedUnavailable, style: text.labelMedium, textAlign: TextAlign.center),
                ),
              ),
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: t.savedRemove,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.bookmark, color: AppColors.primary, size: 20),
                  onPressed: () => _remove(context, ref),
                ),
              ),
            ),
            if (drop != null)
              Positioned(
                left: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    t.savedPriceDrop(Formatters.price(drop)),
                    style: text.labelSmall?.copyWith(color: AppColors.successInk),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (l == null) return image;

    final facts = [
      if (l.year != null) '${l.year}',
      Formatters.km(l.mileageKm),
    ].where((s) => s.isNotEmpty).join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.m),
      onTap: () => context.push(AppRoutes.listingPath(item.listingId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          image,
          const SizedBox(height: AppSpacing.s),
          Text(Formatters.price(l.priceCents), style: text.titleSmall),
          Text(l.title, style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (facts.isNotEmpty) Text(facts, style: text.bodySmall, maxLines: 1),
        ],
      ),
    );
  }
}
