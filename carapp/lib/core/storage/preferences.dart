import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the instance loaded at startup.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// Every local storage key in one place, so nothing collides.
class PrefKeys {
  PrefKeys._();

  static const appConfigCache = 'app_config_cache_v1';
  static const onboardingDone = 'onboarding_done_v1';
  static const userIntent = 'user_intent_v1';
  static const buyerPreferences = 'buyer_preferences_v1';
  static const anonId = 'anon_id_v1';
  static const viewedListingsCount = 'viewed_listings_count_v1';
  static const feedFilters = 'feed_filters_v1';
  static const recentSearches = 'recent_searches_v1';
  static const pendingConsents = 'pending_consents_v1';
}
