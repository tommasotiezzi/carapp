import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/vehicle_labels.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../saved/state/saved_controller.dart';
import '../../saved/ui/save_action.dart';
import '../data/listing_detail.dart';
import '../state/listing_providers.dart';
import 'listing_photos.dart';
import 'listing_questions.dart';
import 'listing_sections.dart';
import 'listing_video_header.dart';

/// `/listing/:id`: video on top, price and total cost, photos, specs,
/// description, seller, Q&A, sticky Contact. Also the target of share links.
class ListingScreen extends ConsumerWidget {
  const ListingScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final listing = ref.watch(listingDetailProvider(id));

    return listing.when(
      loading: () => const _ListingLoading(),
      error: (_, _) => _ListingMessage(
        title: t.errorTitle,
        body: t.errorBody,
        actionLabel: t.commonRetry,
        onAction: () => ref.invalidate(listingDetailProvider(id)),
      ),
      data: (l) => l == null
          ? _ListingMessage(
              title: t.listingNotFoundTitle,
              body: t.listingNotFoundBody,
              actionLabel: t.listingBackToFeed,
              onAction: () => context.go(AppRoutes.feed),
            )
          : _ListingBody(listing: l),
    );
  }
}

/// Back works both when pushed from the feed and when opened by a link.
void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(AppRoutes.feed);

class _ListingBody extends StatefulWidget {
  const _ListingBody({required this.listing});

  final ListingDetail listing;

  @override
  State<_ListingBody> createState() => _ListingBodyState();
}

class _ListingBodyState extends State<_ListingBody> {
  final _scroll = ScrollController();
  final _videoVisible = ValueNotifier(true);
  double _videoHeight = 0;

  @override
  void initState() {
    super.initState();
    // Pause the video once most of it has been scrolled away.
    _scroll.addListener(() {
      _videoVisible.value = _scroll.offset < _videoHeight * 0.7;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _videoVisible.dispose();
    super.dispose();
  }

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).comingSoon(what))));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final l = widget.listing;
    final size = MediaQuery.sizeOf(context);
    _videoHeight = (size.height * 0.62).clamp(0, size.width * 16 / 9).toDouble();

    final facts = [
      l.year?.toString() ?? '',
      Formatters.km(l.mileageKm),
      t.fuelLabel(l.fuelType),
      t.transmissionLabel(l.transmission),
    ].where((s) => s.isNotEmpty).join(' · ');

    const gap = SizedBox(height: AppSpacing.xxxl);
    const page = EdgeInsets.symmetric(horizontal: AppSpacing.page);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // A single scroll view (not a lazy list) so the video player
          // is not disposed and re-downloaded when scrolled out of view.
          SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListingVideoHeader(listing: l, height: _videoHeight, visible: _videoVisible),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.xl, AppSpacing.page, 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.title, style: text.headlineSmall),
                      if ((l.version ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(l.version!, style: text.bodyLarge),
                      ],
                      const SizedBox(height: AppSpacing.s),
                      Text(Formatters.price(l.priceCents), style: text.headlineMedium),
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s),
                        Text(facts, style: text.bodyMedium),
                      ],
                      if (l.location != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 16, color: AppColors.inkMuted),
                            const SizedBox(width: AppSpacing.xxs),
                            Flexible(child: Text(l.location!, style: text.bodyMedium)),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      ListingTotalCost(listing: l),
                    ],
                  ),
                ),
                if (l.photos.isNotEmpty) ...[
                  gap,
                  Padding(padding: page, child: ListingSectionTitle(t.listingPhotos)),
                  ListingPhotoStrip(photos: l.photos),
                ],
                gap,
                Padding(padding: page, child: ListingSpecs(listing: l)),
                if ((l.description ?? '').trim().isNotEmpty) ...[
                  gap,
                  Padding(padding: page, child: ListingDescription(text: l.description!.trim())),
                ],
                gap,
                Padding(padding: page, child: ListingSeller(listing: l)),
                gap,
                Padding(padding: page, child: ListingQuestions(listing: l)),
              ],
            ),
          ),
          // Buttons over the video
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back,
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: () => _back(context),
                  ),
                  const Spacer(),
                  Consumer(
                    builder: (context, ref, _) {
                      final saved = ref.watch(isSavedProvider(l.id));
                      return _RoundButton(
                        icon: saved ? Icons.bookmark : Icons.bookmark_border,
                        tooltip: saved ? t.savedRemove : t.commonSave,
                        onTap: () => toggleSave(context, ref, listingId: l.id, priceCents: l.priceCents),
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.s),
                  _RoundButton(
                    icon: Icons.ios_share,
                    tooltip: t.commonShare,
                    onTap: () => _comingSoon(t.commonShare),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ContactBar(
        priceCents: l.priceCents,
        onContact: () => _comingSoon(t.commonContact),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0x66000000),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: Colors.white, size: 22),
          onPressed: onTap,
        ),
      );
}

/// Sticky bottom bar: price always visible, Contact always one tap away.
class _ContactBar extends StatelessWidget {
  const _ContactBar({required this.priceCents, required this.onContact});

  final int? priceCents;
  final VoidCallback onContact;

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
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.m, AppSpacing.page, AppSpacing.m),
          child: Row(
            children: [
              Text(Formatters.price(priceCents), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: AppSpacing.l),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onContact,
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: Text(t.commonContact),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingLoading extends StatelessWidget {
  const _ListingLoading();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: (size.height * 0.62).clamp(0, size.width * 16 / 9).toDouble(),
                color: AppColors.feedVideoPlaceholder,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: AppSpacing.xxs),
              child: _RoundButton(
                icon: Icons.arrow_back,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onTap: () => _back(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingMessage extends StatelessWidget {
  const _ListingMessage({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

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
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
