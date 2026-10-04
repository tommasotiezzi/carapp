import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/geo/distance_label.dart';
import '../../../core/media/media_url.dart';
import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../data/feed_item.dart';

/// Grid card of a listing (Search results, Salvati): 3:4 cover, price,
/// title, year and km. Tap opens the listing.
/// [item] null = the listing is no longer visible: only [unavailableLabel].
class ListingCard extends ConsumerWidget {
  const ListingCard({
    super.key,
    required this.item,
    this.topRight,
    this.badge,
    this.unavailableLabel,
    this.onOpen,
  });

  final FeedItem? item;

  /// Called before the listing opens (e.g. Search remembers the query).
  final VoidCallback? onOpen;

  /// Over the top-right corner of the cover (e.g. the bookmark).
  final Widget? topRight;

  /// Over the bottom-left corner of the cover (e.g. a price drop).
  final Widget? badge;

  final String? unavailableLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final l = item;
    final cover = l == null ? null : MediaUrl.resolve(ref.read(supabaseProvider), l.coverPath);

    // "Firenze · 50 km da te"
    final distance = l == null
        ? null
        : distanceLabel(AppLocalizations.of(context), home: ref.watch(homeProvinceProvider), province: l.province);
    final place = l == null
        ? null
        : [l.city, distance].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');

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
            if (l == null && unavailableLabel != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  child: Text(unavailableLabel!, style: text.labelMedium, textAlign: TextAlign.center),
                ),
              ),
            if (topRight != null) Positioned(top: AppSpacing.xs, right: AppSpacing.xs, child: topRight!),
            if (badge != null) Positioned(left: AppSpacing.xs, bottom: AppSpacing.xs, child: badge!),
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
      onTap: () {
        onOpen?.call();
        context.push(AppRoutes.listingPath(l.id));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          image,
          const SizedBox(height: AppSpacing.s),
          Text(Formatters.price(l.priceCents), style: text.titleSmall),
          Text(l.title, style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (facts.isNotEmpty) Text(facts, style: text.bodySmall, maxLines: 1),
          if ((place ?? '').isNotEmpty) Text(place!, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Two-column wrap of cards with the standard spacing.
class ListingCardGrid extends StatelessWidget {
  const ListingCardGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - AppSpacing.m) / 2;
          return Wrap(
            spacing: AppSpacing.m,
            runSpacing: AppSpacing.l,
            children: [for (final c in children) SizedBox(width: width, child: c)],
          );
        },
      );
}
