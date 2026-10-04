import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../chat/ui/chat_widgets.dart' show ListingThumb;
import '../../listing/state/listing_providers.dart';
import '../../share/share_listing.dart';

/// `/sell/done/:id` (screen 5): the listing is online. Share it or open it.
class SellDoneScreen extends ConsumerWidget {
  const SellDoneScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final listing = ref.watch(listingDetailProvider(listingId)).value;
    final config = ref.watch(appConfigProvider).value ?? AppConfig.empty;
    final days = (config.section('listing_lifecycle')['confirm_every_days'] as num?)?.toInt() ?? 21;
    final model = listing?.modelName;

    void close() => context.go(AppRoutes.feed);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: close,
                  ),
                ),
                const Spacer(),
                const Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.check, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  model == null ? t.doneTitleGeneric : t.doneTitle(model),
                  style: text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  t.doneBody((days / 7).round()),
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (listing != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    child: Row(
                      children: [
                        ListingThumb(path: listing.coverPath),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [listing.title, listing.version].whereType<String>().join(' '),
                                style: text.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  Formatters.price(listing.priceCents),
                                  listing.year?.toString(),
                                  Formatters.km(listing.mileageKm),
                                ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(flex: 2),
                Builder(
                  // Its own context: the iPad share popover points here.
                  builder: (context) => FilledButton(
                    onPressed: () => shareListing(
                      context,
                      ref,
                      listingId: listingId,
                      summary: listingShareSummary(
                        makeName: listing?.makeName,
                        modelName: listing?.modelName,
                        year: listing?.year,
                        priceCents: listing?.priceCents,
                        city: listing?.city,
                      ),
                    ),
                    child: Text(t.doneShare),
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.listingPath(listingId)),
                  child: Text(t.doneOpen),
                ),
                const SizedBox(height: AppSpacing.l),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
