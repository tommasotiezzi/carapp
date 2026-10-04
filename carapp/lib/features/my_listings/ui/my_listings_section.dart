import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/thousands_formatter.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../chat/ui/chat_widgets.dart' show ListingThumb;
import '../data/my_listings_repository.dart';
import '../state/my_listings_controller.dart';

/// "I miei annunci" in the profile: each listing with its status, how
/// many saved it and chats, the offer to the savers and the actions the
/// status allows. [compact] (buyers who also sell) hides the empty state.
class MyListingsSection extends ConsumerWidget {
  const MyListingsSection({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final listings = ref.watch(myListingsProvider);
    final list = listings.value;

    if (list == null) {
      if (compact) return const SizedBox.shrink();
      return listings.hasError
          ? ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.myListingsTitle, style: text.titleMedium),
              subtitle: Text(t.errorBody),
              trailing: TextButton(
                onPressed: () => ref.invalidate(myListingsProvider),
                child: Text(t.commonRetry),
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Center(child: CircularProgressIndicator()),
            );
    }
    if (list.isEmpty && compact) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('my-listings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(t.myListingsTitle, style: text.titleMedium)),
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.sell),
              icon: const Icon(Icons.add, size: 18),
              label: Text(t.myListingsSell),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: Text(t.myListingsEmpty, style: text.bodyMedium),
          )
        else
          for (final l in list) ...[
            MyListingTile(listing: l),
            const SizedBox(height: AppSpacing.s),
          ],
      ],
    );
  }
}

class MyListingTile extends ConsumerWidget {
  const MyListingTile({super.key, required this.listing});

  final MyListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final l = listing;
    final now = DateTime.now();
    final next = l.nextOfferAt(now);
    final title = [l.title, l.year?.toString()].whereType<String>().join(' · ');

    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: l.status == 'draft' ? null : () => context.push(AppRoutes.listingPath(l.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListingThumb(path: l.coverPath, size: 64),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusTag(status: l.status),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title.isEmpty ? t.myListingUntitled : title,
                          style: text.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(Formatters.price(l.priceCents), style: text.bodyMedium),
                      ],
                    ),
                  ),
                  _Menu(listing: l),
                ],
              ),
              if (l.status != 'draft') ...[
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    const Icon(Icons.bookmark_border, size: 16, color: AppColors.inkSecondary),
                    const SizedBox(width: 4),
                    Flexible(child: Text(t.myListingSaves(l.saves), style: text.bodySmall)),
                    const SizedBox(width: AppSpacing.m),
                    const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.inkSecondary),
                    const SizedBox(width: 4),
                    Text(t.myListingChats(l.chats), style: text.bodySmall),
                  ],
                ),
              ],
              if (l.isActive && l.saves > 0) ...[
                const SizedBox(height: AppSpacing.s),
                if (next == null)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => showOfferSheet(context, l),
                    icon: const Icon(Icons.local_offer_outlined, size: 18),
                    label: Text(t.myListingOffer),
                  )
                else
                  Text(
                    t.myListingOfferSent(
                      Formatters.price(l.lastOfferPriceCents),
                      next.difference(now).inHours + 1,
                    ),
                    style: text.bodySmall?.copyWith(color: AppColors.primary),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      'active' => (t.myListingActive, AppColors.success),
      'sold' => (t.myListingSold, AppColors.primary),
      'draft' => (t.myListingDraft, AppColors.inkSecondary),
      _ => (t.myListingExpired, AppColors.inkSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// What the status allows (see `protect_listing_fields`).
class _Menu extends ConsumerWidget {
  const _Menu({required this.listing});

  final MyListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final l = listing;

    Future<void> run(Future<void> Function() action) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
      } catch (_) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.myListingError)));
      }
    }

    Future<void> remove() async {
      final controller = ref.read(myListingsProvider.notifier);
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.myListingRemoveTitle),
          content: Text(t.myListingRemoveBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.commonUndo)),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.myListingRemove, style: const TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );
      if (ok == true) await run(() => controller.setStatus(l.id, 'removed'));
    }

    final items = <(String, String)>[
      if (l.isActive || l.status == 'sold') ('edit', t.editListingTitle),
      if (l.isActive || l.status == 'sold') ('media', t.editListingMedia),
      if (l.isActive) ('price', t.myListingEditPrice),
      if (l.isActive) ('sold', t.myListingMarkSold),
      if (l.status == 'sold') ('relist', t.myListingRelist),
      if (l.isActive || l.status == 'draft') ('remove', t.myListingRemove),
    ];
    if (items.isEmpty) return const SizedBox(width: 48);

    return PopupMenuButton<String>(
      tooltip: t.myListingActions,
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        final controller = ref.read(myListingsProvider.notifier);
        switch (value) {
          case 'edit':
            context.push(AppRoutes.editListingPath(l.id));
          case 'media':
            context.push(AppRoutes.editMediaPath(l.id));
          case 'price':
            showPriceSheet(context, l);
          case 'sold':
            run(() => controller.setStatus(l.id, 'sold'));
          case 'relist':
            run(() => controller.setStatus(l.id, 'active'));
          case 'remove':
            remove();
        }
      },
      itemBuilder: (_) => [
        for (final (value, label) in items)
          PopupMenuItem(
            value: value,
            child: Text(label, style: value == 'remove' ? const TextStyle(color: AppColors.danger) : null),
          ),
      ],
    );
  }
}

/// "Offerta a chi l'ha salvato": a reserved price for everyone who saved
/// the listing; they get a message in their Inbox and can answer at once.
Future<void> showOfferSheet(BuildContext context, MyListing listing) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PriceSheet(listing: listing, offer: true),
    );

/// "Cambia prezzo": the public price (who saved it sees the drop).
Future<void> showPriceSheet(BuildContext context, MyListing listing) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PriceSheet(listing: listing, offer: false),
    );

class _PriceSheet extends ConsumerStatefulWidget {
  const _PriceSheet({required this.listing, required this.offer});

  final MyListing listing;
  final bool offer;

  @override
  ConsumerState<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends ConsumerState<_PriceSheet> {
  late final _price = TextEditingController(
    text: widget.offer ? ThousandsFormatter.format(_suggested(5)) : ThousandsFormatter.format(_euros),
  );
  bool _sending = false;
  String? _error;

  int get _euros => (widget.listing.priceCents ?? 0) ~/ 100;

  /// [percent] off, rounded down to 50 €.
  int _suggested(int percent) => (_euros * (100 - percent) / 100 / 50).floor() * 50;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  String? _validate(AppLocalizations t, int? euros) {
    if (euros == null || euros <= 0) return t.offerErrorEmpty;
    if (!widget.offer) return null;
    if (euros >= _euros) return t.offerErrorNotLower;
    if (euros * 2 < _euros) return t.offerErrorTooLow;
    return null;
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final euros = ThousandsFormatter.parse(_price.text);
    final error = _validate(t, euros);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final controller = ref.read(myListingsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (widget.offer) {
        final n = await controller.offer(widget.listing.id, euros! * 100);
        navigator.pop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.offerSent(n))));
      } else {
        await controller.updatePrice(widget.listing.id, euros! * 100);
        navigator.pop();
      }
    } on OfferException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = switch (e.failure) {
          OfferFailure.notLower => t.offerErrorNotLower,
          OfferFailure.tooLow => t.offerErrorTooLow,
          OfferFailure.tooSoon => t.offerErrorTooSoon,
          OfferFailure.noSavers => t.offerErrorNoSavers,
          OfferFailure.unavailable => t.offerErrorUnavailable,
          OfferFailure.other => t.offerError,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = widget.offer ? t.offerError : t.myListingError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final l = widget.listing;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.l, AppSpacing.page, AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.offer ? t.offerSheetTitle : t.myListingEditPrice, style: text.titleLarge),
              const SizedBox(height: AppSpacing.s),
              Text(
                widget.offer ? t.offerSheetBody(l.saves, Formatters.price(l.priceCents)) : t.priceSheetBody,
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.l),
              TextField(
                controller: _price,
                autofocus: !widget.offer,
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsFormatter()],
                style: text.headlineSmall,
                decoration: InputDecoration(
                  labelText: widget.offer ? t.offerSheetPrice : t.priceSheetPrice,
                  prefixText: '€ ',
                  prefixStyle: text.headlineSmall,
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              if (widget.offer) ...[
                const SizedBox(height: AppSpacing.s),
                Wrap(
                  spacing: AppSpacing.s,
                  children: [
                    for (final p in const [3, 5, 10])
                      ActionChip(
                        label: Text('−$p%'),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _price.text = ThousandsFormatter.format(_suggested(p));
                          setState(() => _error = null);
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.l),
              FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(widget.offer ? t.offerSheetSend(l.saves) : t.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
