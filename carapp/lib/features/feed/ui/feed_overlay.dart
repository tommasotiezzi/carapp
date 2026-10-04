import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/l10n/vehicle_labels.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/feed_item.dart';

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
  });

  final FeedItem item;
  final bool saved;
  final VoidCallback onOpenDetail;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onContact;
  final VoidCallback onOpenFilters;

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
          child: _Caption(item: item, onTap: onOpenDetail),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: _FilterPills(onTap: onOpenFilters),
        ),
      ],
    );
  }
}

class _SideActions extends StatelessWidget {
  const _SideActions({
    required this.item,
    required this.saved,
    required this.onSave,
    required this.onShare,
    required this.onContact,
  });

  final FeedItem item;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF2C333C),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                Formatters.initials(item.sellerName),
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
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
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
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
  const _Caption({required this.item, required this.onTap});

  final FeedItem item;
  final VoidCallback onTap;

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
          Row(
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
              style: const TextStyle(
                color: Color(0xE6FFFFFF),
                fontSize: 14,
                shadows: shadow,
              ),
            ),
          ],
          if ((item.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 13,
                height: 1.4,
                shadows: shadow,
              ),
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

/// Liquid-glass pills. For now they open the search tab;
/// they will show the user's active filters once search is built.
class _FilterPills extends StatelessWidget {
  const _FilterPills({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.chipHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        children: [
          _GlassPill(onTap: onTap, child: const Icon(Icons.tune, size: 16, color: Colors.white)),
          const SizedBox(width: 8),
          _GlassPill(onTap: onTap, label: 'Prezzo'),
          const SizedBox(width: 8),
          _GlassPill(onTap: onTap, label: 'Marca'),
          const SizedBox(width: 8),
          _GlassPill(onTap: onTap, label: 'Anno'),
          const SizedBox(width: 8),
          _GlassPill(onTap: onTap, label: 'Km'),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.onTap, this.label, this.child});

  final VoidCallback onTap;
  final String? label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: AppColors.glassFill,
          shape: const StadiumBorder(side: BorderSide(color: AppColors.glassBorder)),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: child ??
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white),
                      ],
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
