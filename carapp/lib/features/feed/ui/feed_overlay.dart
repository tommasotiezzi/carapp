import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/vehicle_labels.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../onboarding/data/catalog_repository.dart';
import '../data/feed_filters.dart';
import '../data/feed_item.dart';
import '../state/feed_filters_controller.dart';
import '../../search/data/catalog.dart';
import 'filter_summary.dart';

/// Everything drawn over the video: side actions, caption, filter pills.
class FeedOverlay extends StatelessWidget {
  const FeedOverlay({
    super.key,
    required this.item,
    required this.onOpenDetail,
    required this.saved,
    required this.onSave,
    required this.onShare,
    required this.onContact,
    required this.onOpenFilters,
    this.onOpenSeller,
  });

  final FeedItem item;

  /// The seller's page (avatar or name); null = no page (old rows).
  final VoidCallback? onOpenSeller;
  final bool saved;
  final VoidCallback onOpenDetail;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onContact;

  /// null = the "tune" button (all filters), otherwise one pill's section.
  final ValueChanged<FilterSection?> onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Readability gradient under the caption
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 360,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xD1000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 120,
          child: _SideActions(
            item: item,
            onOpenSeller: onOpenSeller,
            saved: saved,
            onSave: onSave,
            onShare: onShare,
            onContact: onContact,
          ),
        ),
        Positioned(
          left: AppSpacing.page,
          right: 84,
          bottom: 64,
          child: _Caption(item: item, onTap: onOpenDetail, onOpenSeller: onOpenSeller),
        ),
        Positioned(left: 0, right: 0, bottom: 12, child: _FilterPills(onOpen: onOpenFilters)),
      ],
    );
  }
}

class _SideActions extends StatelessWidget {
  const _SideActions({
    required this.item,
    this.onOpenSeller,
    required this.saved,
    required this.onSave,
    required this.onShare,
    required this.onContact,
  });

  final FeedItem item;
  final VoidCallback? onOpenSeller;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpenSeller,
          child: Semantics(
            button: onOpenSeller != null,
            label: item.sellerName,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: UserAvatar(path: item.avatarPath, name: item.sellerName, radius: 22, dark: true),
                ),
                if (item.isDealer)
                  Positioned(
                    bottom: -7,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.feedBackground, width: 2),
                      ),
                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _ActionButton(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          label: saved ? AppLocalizations.of(context).savedLabel : AppLocalizations.of(context).commonSave,
          onTap: onSave,
        ),
        const SizedBox(height: 18),
        _ActionButton(icon: Icons.reply, label: 'Invia', onTap: onShare, mirror: true),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: 'Contatta',
          onTap: onContact,
          highlighted: true,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.mirror = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    Widget glyph = Icon(icon, size: highlighted ? 24 : 32, color: Colors.white);
    if (mirror) {
      glyph = Transform.flip(flipX: true, child: glyph);
    }

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 56,
          child: Column(
            children: [
              if (highlighted)
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Center(child: glyph),
                )
              else
                glyph,
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 6, color: Color(0x66000000))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.item, required this.onTap, this.onOpenSeller});

  final FeedItem item;
  final VoidCallback onTap;
  final VoidCallback? onOpenSeller;

  @override
  Widget build(BuildContext context) {
    final specs = [
      if (item.year != null) '${item.year}',
      Formatters.km(item.mileageKm),
      AppLocalizations.of(context).fuelLabel(item.fuelType),
      Formatters.horsepower(item.powerKw),
    ].where((s) => s.isNotEmpty).join(' · ');

    const shadow = [Shadow(blurRadius: 8, color: Color(0x80000000))];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenSeller ?? onTap,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: shadow,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x2EFFFFFF),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    item.isDealer ? 'Concessionario' : 'Privato',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              color: Colors.white,
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w700,
              shadows: shadow,
            ),
          ),
          if (specs.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              specs,
              style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14, shadows: shadow),
            ),
          ],
          if ((item.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13, height: 1.4, shadows: shadow),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            Formatters.price(item.priceCents),
            style: const TextStyle(
              fontFamily: AppFonts.display,
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              shadows: shadow,
            ),
          ),
        ],
      ),
    );
  }
}

/// Liquid-glass pills showing the active filters. A pill opens its
/// section; the "tune" button opens every filter and shows how many are on.
class _FilterPills extends ConsumerWidget {
  const _FilterPills({required this.onOpen});

  final ValueChanged<FilterSection?> onOpen;

  static final _thousands = NumberFormat.decimalPattern('it_IT');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(feedFiltersProvider);

    String brandLabel() {
      if (f.modelIds.isNotEmpty) {
        // Models come from the Search box; names need the catalog.
        final catalog = ref.watch(catalogProvider).value;
        final model = f.modelIds.length == 1 ? catalog?.modelById[f.modelIds.first] : null;
        return model?.name ?? t.filterModelCount(f.modelIds.length);
      }
      if (f.makeIds.isEmpty) return t.filterBrand;
      if (f.makeIds.length > 1) return t.filterBrandCount(f.makeIds.length);
      final makes = ref.watch(makesProvider(f.categoryId ?? 'car')).value ?? const [];
      return makes.where((m) => m.id == f.makeIds.first).firstOrNull?.name ?? t.filterBrandCount(1);
    }

    final pills = [
      (
        FilterSection.distance,
        f.hasDistance,
        f.hasDistance ? t.distanceWithin(f.radiusKm!) : t.filterDistance,
      ),
      (FilterSection.price, f.hasPrice, priceLabel(t, f)),
      (FilterSection.brand, f.hasBrand, brandLabel()),
      (FilterSection.year, f.hasYear, yearLabel(t, f)),
      (
        FilterSection.mileage,
        f.mileageMaxKm != null,
        f.mileageMaxKm != null ? t.mileageMax(_thousands.format(f.mileageMaxKm)) : t.filterMileage,
      ),
    ];

    return SizedBox(
      height: AppSizes.chipHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        children: [
          _GlassPill(
            onTap: () => onOpen(null),
            active: !f.isEmpty,
            semanticLabel: t.filterTitle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, size: 16, color: f.isEmpty ? Colors.white : AppColors.ink),
                if (!f.isEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${f.activeCount}',
                    style: const TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          for (final (section, active, label) in pills) ...[
            const SizedBox(width: 8),
            _GlassPill(onTap: () => onOpen(section), active: active, label: label),
          ],
        ],
      ),
    );
  }
}

/// Active = solid white with dark text, readable on any video frame.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.onTap, this.active = false, this.label, this.child, this.semanticLabel});

  final VoidCallback onTap;
  final bool active;
  final String? label;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppColors.ink : Colors.white;

    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: active ? Colors.white : AppColors.glassFill,
            shape: StadiumBorder(side: BorderSide(color: active ? Colors.white : AppColors.glassBorder)),
            child: InkWell(
              onTap: onTap,
              customBorder: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child:
                      child ??
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label!,
                            style: TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 16, color: foreground),
                        ],
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
