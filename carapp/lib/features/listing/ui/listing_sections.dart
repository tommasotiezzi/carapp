import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/vehicle_labels.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/listing_detail.dart';
import '../data/transfer_cost.dart';
import '../state/listing_providers.dart';

/// Title above each block of the listing screen.
class ListingSectionTitle extends StatelessWidget {
  const ListingSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.m),
        child: Row(
          children: [
            Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
            ?trailing,
          ],
        ),
      );
}

/// Two-column grid of the vehicle data; empty values are skipped.
class ListingSpecs extends StatelessWidget {
  const ListingSpecs({super.key, required this.listing});

  final ListingDetail listing;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = listing;
    final power = l.powerKw == null ? '' : '${l.powerKw} kW (${Formatters.horsepower(l.powerKw)})';

    final specs = <(String, String)>[
      (t.specYear, l.year?.toString() ?? ''),
      (t.specMileage, Formatters.km(l.mileageKm)),
      (t.specFuel, t.fuelLabel(l.fuelType)),
      (t.specTransmission, t.transmissionLabel(l.transmission)),
      (t.specPower, power),
      (t.specEuroClass, l.euroClass == null ? '' : t.specEuroValue(l.euroClass!)),
      (t.specColor, l.color ?? ''),
      (t.specOwners, l.ownersCount?.toString() ?? ''),
      (t.specServiceHistory, switch (l.hasServiceHistory) {
        true => t.commonYes,
        false => t.commonNo,
        null => '',
      }),
      (t.specWarranty, (l.warrantyMonths ?? 0) > 0 ? t.specWarrantyMonths(l.warrantyMonths!) : ''),
    ].where((s) => s.$2.trim().isNotEmpty).toList();

    if (specs.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListingSectionTitle(t.listingSpecs),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = (constraints.maxWidth - AppSpacing.m) / 2;
            return Wrap(
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.m,
              children: [
                for (final (label, value) in specs)
                  Container(
                    width: cellWidth,
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: text.bodySmall),
                        const SizedBox(height: 2),
                        Text(value, style: text.titleSmall),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Price + estimated ownership transfer. Hidden when it cannot be estimated.
class ListingTotalCost extends ConsumerWidget {
  const ListingTotalCost({super.key, required this.listing});

  final ListingDetail listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = listing.priceCents;
    final config = ref.watch(appConfigProvider).value ?? AppConfig.empty;
    final transfer = TransferCostRules.fromConfig(config.section('transfer_costs'))
        .estimateCents(categoryId: listing.categoryId, powerKw: listing.powerKw);
    if (price == null || transfer == null) return const SizedBox.shrink();

    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    Widget row(String label, int cents, {bool total = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            children: [
              Expanded(child: Text(label, style: total ? text.titleMedium : text.bodyLarge)),
              Text(
                Formatters.price(cents),
                style: total ? text.titleMedium : text.bodyLarge,
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.costTitle, style: text.titleMedium),
          const SizedBox(height: AppSpacing.s),
          row(t.costPrice, price),
          row(t.costTransfer, transfer),
          const Divider(height: AppSpacing.l, color: AppColors.borderStrong),
          row(t.costTotal, price + transfer, total: true),
          const SizedBox(height: AppSpacing.s),
          Text(t.costNote, style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Seller description, collapsed to a few lines when long.
class ListingDescription extends StatefulWidget {
  const ListingDescription({super.key, required this.text});

  final String text;

  @override
  State<ListingDescription> createState() => _ListingDescriptionState();
}

class _ListingDescriptionState extends State<ListingDescription> {
  static const _collapsedLines = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodyLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListingSectionTitle(t.listingDescription),
        LayoutBuilder(
          builder: (context, constraints) {
            // Show the toggle only if the text really overflows.
            final painter = TextPainter(
              text: TextSpan(text: widget.text, style: style),
              maxLines: _collapsedLines,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: constraints.maxWidth);
            final overflows = painter.didExceedMaxLines;
            painter.dispose();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.text,
                  style: style,
                  maxLines: _expanded ? null : _collapsedLines,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                if (overflows)
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? t.listingShowLess : t.listingShowMore),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Dealer card (with reviews when enabled) or anonymous private seller.
class ListingSeller extends ConsumerWidget {
  const ListingSeller({super.key, required this.listing});

  final ListingDetail listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final dealer = listing.isDealer ? listing.dealer : null;
    final config = ref.watch(appConfigProvider).value ?? AppConfig.empty;
    final showReviews = dealer != null && config.flag('reviews_enabled');

    final name = dealer?.displayName ?? t.sellerPrivate;
    final location = dealer == null
        ? listing.location
        : [dealer.city, if ((dealer.province ?? '').isNotEmpty) '(${dealer.province})']
            .whereType<String>()
            .join(' ');
    final subtitle = [
      if (dealer != null) t.sellerDealer,
      if ((location ?? '').trim().isNotEmpty) location!,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListingSectionTitle(t.sellerTitle),
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: dealer == null ? AppColors.placeholder : AppColors.primary,
              child: dealer == null
                  ? const Icon(Icons.person_outline, color: AppColors.inkSecondary)
                  : Text(
                      Formatters.initials(dealer.displayName),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle.isNotEmpty) Text(subtitle, style: text.bodyMedium),
                  if (dealer?.vatVerified ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, size: 16, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.xxs),
                          Flexible(child: Text(t.sellerVatVerified, style: text.labelMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (showReviews) ...[
          const SizedBox(height: AppSpacing.l),
          _DealerReviews(dealerId: dealer.id),
        ],
      ],
    );
  }
}

class _DealerReviews extends ConsumerWidget {
  const _DealerReviews({required this.dealerId});

  final String dealerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final reviews = ref.watch(dealerReviewsProvider(dealerId)).value;
    if (reviews == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (reviews.average != null) ...[
              _Stars(rating: reviews.average!),
              const SizedBox(width: AppSpacing.s),
              Text(reviews.average!.toStringAsFixed(1).replaceAll('.', ','), style: text.titleSmall),
              const SizedBox(width: AppSpacing.s),
            ],
            Flexible(child: Text(t.reviewsCount(reviews.count), style: text.bodyMedium)),
          ],
        ),
        for (final r in reviews.latest) ...[
          const SizedBox(height: AppSpacing.m),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Stars(rating: r.rating.toDouble(), size: 14),
                const SizedBox(height: AppSpacing.xxs),
                Text(r.body!, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 18});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              rating >= i
                  ? Icons.star_rounded
                  : (rating >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
              size: size,
              color: AppColors.rating,
            ),
        ],
      );
}
