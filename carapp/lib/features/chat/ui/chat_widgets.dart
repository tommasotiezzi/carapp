import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_url.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/chat_models.dart';

/// The other side's name, with a fallback when a user has none.
String otherNameOf(ConversationSummary c, AppLocalizations t) {
  final name = c.otherName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  return c.isBuyer ? t.chatPrivateSeller : t.chatBuyer;
}

/// "Venduto" / "Non più disponibile", null while the listing is active.
String? listingStatusLabel(String status, AppLocalizations t) => switch (status) {
      'active' => null,
      'sold' => t.chatListingSold,
      _ => t.chatListingUnavailable,
    };

/// Square listing cover with a neutral placeholder.
class ListingThumb extends ConsumerWidget {
  const ListingThumb({super.key, required this.path, this.size = 52});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = MediaUrl.resolve(ref.read(supabaseProvider), path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(
              color: AppColors.placeholder,
              child: Icon(Icons.directions_car_outlined, color: AppColors.inkMuted, size: 22),
            ),
            if (url != null)
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: (size * 3).round(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small grey label, e.g. "Venduto" or "Il tuo annuncio".
class ChatTag extends StatelessWidget {
  const ChatTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.inkSecondary),
        ),
      );
}
