import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/geo/italian_capitals.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../onboarding/state/onboarding_controller.dart';

/// One card of "Concessionari vicino a te" (`dealers_near()`).
class NearbyDealer {
  const NearbyDealer({
    required this.id,
    required this.name,
    required this.activeListings,
    this.logoPath,
    this.city,
    this.province,
    this.verified = false,
  });

  final String id;
  final String name;
  final int activeListings;
  final String? logoPath;
  final String? city;
  final String? province;
  final bool verified;

  factory NearbyDealer.fromRow(Map<String, dynamic> row) => NearbyDealer(
        id: row['id'] as String,
        name: row['display_name'] as String,
        activeListings: (row['active_listings'] as num).toInt(),
        logoPath: row['logo_path'] as String?,
        city: row['city'] as String?,
        province: row['province'] as String?,
        verified: (row['verified'] as bool?) ?? false,
      );
}

/// Where "vicino a te" is measured from: the user's capital and how far
/// they said they would go (100 km when they chose "Tutta Italia").
class NearbyArea {
  const NearbyArea(this.center, this.radiusKm);

  final String center;
  final int radiusKm;

  static const defaultRadiusKm = 100;
}

final nearbyAreaProvider = Provider<NearbyArea?>((ref) {
  final prefs = ref.watch(onboardingControllerProvider.select((s) => s.preferences));
  final center = prefs.province;
  if (center == null) return null;
  return NearbyArea(center, prefs.maxDistanceKm ?? NearbyArea.defaultRadiusKm);
});

/// Dealers with active listings in the provinces in range, most listings
/// first. One request; null area = nothing to ask.
final nearbyDealersProvider = FutureProvider.autoDispose<List<NearbyDealer>>((ref) async {
  final area = ref.watch(nearbyAreaProvider);
  if (area == null) return const [];
  final provinces = ItalianCapitals.within(area.center, area.radiusKm).toList()..sort();
  final rows = await ref.watch(supabaseProvider).rpc<List<dynamic>>(
    'dealers_near',
    params: {'p_provinces': provinces, 'p_limit': 20},
  );
  return rows.cast<Map<String, dynamic>>().map(NearbyDealer.fromRow).toList();
});
