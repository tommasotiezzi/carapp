import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pill.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/ui/login_sheet.dart';
import '../../chat/ui/contact_actions.dart' show whatsappDigits;
import '../../feed/data/feed_filters.dart';
import '../../feed/data/feed_repository.dart';
import '../../feed/ui/filter_sheet.dart';
import '../../feed/ui/filter_summary.dart';
import '../../feed/ui/listing_card.dart';
import '../../listing/state/listing_providers.dart';
import '../../listing/ui/listing_sections.dart' show DealerReviewsSummary;
import '../../search/data/catalog.dart';
import '../data/seller_repository.dart';
import '../state/seller_providers.dart';

/// `/dealers/:id` and `/seller/:id`: the same page for dealers and
/// private sellers. Header (name, place, contacts the seller chose to
/// show), then their listings as a grid with their own filters; dealers
/// also have a "Recensioni" tab.
class SellerScreen extends ConsumerStatefulWidget {
  const SellerScreen({super.key, required this.seller});

  final SellerRef seller;

  @override
  ConsumerState<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends ConsumerState<SellerScreen> {
  bool _reviews = false;

  void _back() => context.canPop() ? context.pop() : context.go(AppRoutes.feed);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final profile = ref.watch(sellerProfileProvider(widget.seller));
    final config = ref.watch(appConfigProvider).value ?? AppConfig.empty;
    final p = profile.value;
    final showReviews = widget.seller.isDealer && config.flag('reviews_enabled');

    Widget body;
    if (profile.hasError && p == null) {
      body = _Message(
        title: t.errorTitle,
        body: t.errorBody,
        action: t.commonRetry,
        onAction: () => ref.invalidate(sellerProfileProvider(widget.seller)),
      );
    } else if (profile.isLoading && p == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (p == null) {
      body = _Message(title: t.sellerNotFoundTitle, body: t.sellerNotFoundBody);
    } else {
      body = CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(profile: p)),
          if (showReviews)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.l, AppSpacing.page, 0),
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, label: Text(t.sellerTabListings)),
                    ButtonSegment(value: true, label: Text(t.sellerTabReviews)),
                  ],
                  selected: {_reviews},
                  onSelectionChanged: (s) => setState(() => _reviews = s.first),
                ),
              ),
            ),
          if (_reviews && showReviews)
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.page),
              sliver: SliverToBoxAdapter(child: _Reviews(dealerId: widget.seller.id)),
            )
          else
            ..._listings(context),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: Text(p == null ? '' : _displayName(t, p), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: body,
    );
  }

  List<Widget> _listings(BuildContext context) {
    final t = AppLocalizations.of(context);
    final seller = widget.seller;
    final listings = ref.watch(sellerListingsProvider(seller));
    final filters = ref.watch(sellerFiltersProvider(seller));
    final setFilters = ref.read(sellerFiltersProvider(seller).notifier).set;
    final catalog = ref.watch(catalogProvider).value;
    // The category has its own pills above.
    final chips = filterChips(t, filters.copyWith(categoryId: null), catalog);
    final state = listings.value;

    // Distance makes no sense inside one seller's page.
    final sections = [for (final s in FilterSection.values) if (s != FilterSection.distance) s];

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.l, AppSpacing.page, AppSpacing.s),
          child: Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              for (final (id, label) in [(null, t.vehicleAll), ('car', t.vehicleCar), ('motorcycle', t.vehicleMotorcycle)])
                Pill(
                  label: label,
                  selected: filters.categoryId == id,
                  onTap: () => setFilters(filters.copyWith(categoryId: id, makeIds: const {}, modelIds: const {})),
                ),
              Pill(
                label: filters.isEmpty ? t.filterTitle : '${t.filterTitle} · ${filters.activeCount}',
                selected: !filters.isEmpty,
                onTap: () => showFilterSheet(
                  context,
                  initial: filters,
                  onApply: setFilters,
                  sections: sections,
                ),
              ),
            ],
          ),
        ),
      ),
      if (chips.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.s),
            child: Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                for (final c in chips)
                  InputChip(label: Text(c.label), onDeleted: () => setFilters(c.remove(filters))),
              ],
            ),
          ),
        ),
      if (state == null && listings.hasError)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Message(
            title: t.errorTitle,
            body: t.errorBody,
            action: t.commonRetry,
            onAction: () => ref.invalidate(sellerListingsProvider(seller)),
          ),
        )
      else if (state == null)
        const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
      else if (state.items.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Message(
            title: filters.isEmpty ? t.sellerNoListings : t.sellerNoMatches,
            action: filters.isEmpty ? null : t.filterClearAll,
            onAction: () => setFilters(FeedFilters.empty),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s, AppSpacing.page, AppSpacing.xxl),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The previous grid stays while new filters load.
                AnimatedOpacity(
                  opacity: listings.isLoading ? 0.5 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: ListingCardGrid(children: [for (final item in state.items) ListingCard(item: item)]),
                ),
                if (state.hasMore) ...[
                  const SizedBox(height: AppSpacing.l),
                  OutlinedButton(
                    onPressed: state.loadingMore
                        ? null
                        : () => ref.read(sellerListingsProvider(seller).notifier).loadMore(),
                    child: Text(t.searchLoadMore),
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
  }
}

String _displayName(AppLocalizations t, SellerProfile p) =>
    (p.name ?? '').isNotEmpty ? p.name! : (p.isDealer ? t.sellerDealer : t.sellerPrivate);

class _Header extends ConsumerWidget {
  const _Header({required this.profile});

  final SellerProfile profile;

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errorBody)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final p = profile;
    final name = _displayName(t, p);
    final count = ref.watch(sellerListingCountProvider(p.ref)).value;
    final signedIn = ref.watch(currentUserIdProvider) != null;
    final since = p.memberSince == null ? null : DateFormat.yMMMM('it').format(p.memberSince!);
    final reviews = p.isDealer ? ref.watch(dealerReviewsProvider(p.ref.id)).value : null;

    // A private seller's number is only sent to signed-in users.
    Future<void> needLogin() async {
      final ok = await showLoginSheet(context);
      if (ok) ref.invalidate(sellerProfileProvider(p.ref));
    }

    final phone = p.phone;
    final wa = p.whatsapp == null ? null : whatsappDigits(p.whatsapp!);
    final website = p.website == null
        ? null
        : Uri.tryParse(p.website!.startsWith('http') ? p.website! : 'https://${p.website}');

    final buttons = <Widget>[
      if (phone != null)
        OutlinedButton.icon(
          onPressed: () => _open(context, Uri(scheme: 'tel', path: phone.replaceAll(' ', ''))),
          icon: const Icon(Icons.call_outlined, size: 18),
          label: Text(t.sellerCall),
        ),
      if (wa != null)
        OutlinedButton.icon(
          onPressed: () => _open(context, Uri.https('wa.me', '/$wa')),
          icon: const Icon(Icons.chat_outlined, size: 18),
          label: Text(t.whatsappLabel),
        ),
      if (website != null)
        OutlinedButton.icon(
          onPressed: () => _open(context, website),
          icon: const Icon(Icons.language, size: 18),
          label: Text(t.sellerWebsite),
        ),
      if (!signedIn && phone == null && (p.hasPhone || p.hasWhatsapp))
        OutlinedButton.icon(
          onPressed: needLogin,
          icon: const Icon(Icons.lock_outline, size: 18),
          label: Text(t.sellerLoginForContacts),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s, AppSpacing.page, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: p.isDealer ? AppColors.primary : AppColors.placeholder,
                child: Text(
                  Formatters.initials(name),
                  style: TextStyle(
                    color: p.isDealer ? Colors.white : AppColors.inkSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name, style: text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        if (p.verified) ...[
                          const SizedBox(width: AppSpacing.xxs),
                          Tooltip(
                            message: t.sellerVatVerified,
                            child: const Icon(Icons.verified, size: 20, color: AppColors.primary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [p.isDealer ? t.sellerDealer : t.sellerPrivateShort, ?p.place].join(' · '),
                      style: text.bodyMedium,
                    ),
                    if (since != null)
                      Text(t.sellerMemberSince(t.appName, since), style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              if (count != null) Text(t.sellerListingsCount(count), style: text.titleSmall),
              if (reviews?.average != null) ...[
                const SizedBox(width: AppSpacing.m),
                const Icon(Icons.star, size: 16, color: AppColors.rating),
                const SizedBox(width: 2),
                Text(
                  '${reviews!.average!.toStringAsFixed(1).replaceAll('.', ',')} (${reviews.count})',
                  style: text.titleSmall,
                ),
              ],
            ],
          ),
          if ((p.description ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Text(p.description!, style: text.bodyMedium, maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Wrap(spacing: AppSpacing.s, runSpacing: AppSpacing.s, children: buttons),
          ],
        ],
      ),
    );
  }
}

class _Reviews extends ConsumerWidget {
  const _Reviews({required this.dealerId});

  final String dealerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(dealerReviewsProvider(dealerId)).value;
    if (reviews == null) return const Center(child: CircularProgressIndicator());
    if (reviews.count == 0) {
      return Text(AppLocalizations.of(context).sellerNoReviews, style: Theme.of(context).textTheme.bodyMedium);
    }
    return DealerReviewsSummary(dealerId: dealerId);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.body, this.action, this.onAction});

  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text(body!, style: text.bodyMedium, textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.l),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
