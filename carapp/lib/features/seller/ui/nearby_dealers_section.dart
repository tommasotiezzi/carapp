import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/geo/capital_picker.dart';
import '../../../core/geo/distance_label.dart';
import '../../../core/geo/italian_capitals.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../data/nearby_dealers.dart';

/// "Concessionari vicino a te" at the top of Search: a horizontal row of
/// dealers with listings in range; tap opens the dealer's page. Without a
/// capital it asks for one ("Dove sei?").
class NearbyDealersSection extends ConsumerWidget {
  const NearbyDealersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final area = ref.watch(nearbyAreaProvider);

    Future<void> pickPlace() async {
      final onboarding = ref.read(onboardingControllerProvider.notifier);
      final code = await showCapitalPicker(context);
      if (code == null) return;
      onboarding.updatePreferences((p) => p.copyWith(province: code));
      await onboarding.savePreferences();
    }

    final header = [
      Text(t.nearbyDealersTitle, style: text.titleLarge),
      if (area != null)
        Text(
          t.nearbyDealersWithin(area.radiusKm, ItalianCapitals.byCode[area.center]?.name ?? area.center),
          style: text.bodySmall,
        ),
      const SizedBox(height: AppSpacing.m),
    ];

    if (area == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...header,
          Material(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.m),
            child: ListTile(
              leading: const Icon(Icons.place_outlined, color: AppColors.primary),
              title: Text(t.nearbyDealersSetPlace, style: text.bodyMedium),
              trailing: const Icon(Icons.chevron_right),
              onTap: pickPlace,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      );
    }

    final dealers = ref.watch(nearbyDealersProvider);
    final list = dealers.value;
    // Loading or failed: the section simply waits / stays away.
    if (list == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...header,
        if (list.isEmpty)
          Text(t.nearbyDealersNone(area.radiusKm), style: text.bodyMedium)
        else
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.m),
              itemBuilder: (context, i) => _DealerCard(dealer: list[i], home: area.center),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _DealerCard extends StatelessWidget {
  const _DealerCard({required this.dealer, required this.home});

  final NearbyDealer dealer;
  final String home;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final d = dealer;
    final distance = distanceLabel(t, home: home, province: d.province);

    return SizedBox(
      width: 140,
      child: Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.m),
          onTap: () => context.push(AppRoutes.sellerPagePath(id: d.id, dealer: true)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              children: [
                UserAvatar(path: d.logoPath, name: d.name, radius: 28, dealer: true),
                const SizedBox(height: AppSpacing.s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        d.name,
                        style: text.titleSmall,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (d.verified) ...[
                      const SizedBox(width: 2),
                      const Icon(Icons.verified, size: 14, color: AppColors.primary),
                    ],
                  ],
                ),
                const Spacer(),
                Text(t.sellerListingsCount(d.activeListings), style: text.bodySmall),
                if (distance != null)
                  Text(distance, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
