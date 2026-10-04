import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../data/feed_filters.dart';

/// Active feed filters, kept on the phone.
/// Until the user touches them they follow the onboarding preferences
/// ("Cosa cerchi?"); once applied from a sheet, the user's choice wins.
class FeedFiltersController extends Notifier<FeedFilters> {
  @override
  FeedFilters build() {
    final raw = ref.read(sharedPreferencesProvider).getString(PrefKeys.feedFilters);
    if (raw != null) {
      try {
        return FeedFilters.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    final preferences = ref.watch(onboardingControllerProvider.select((s) => s.preferences));
    return FeedFilters.fromPreferences(preferences);
  }

  /// No-op when nothing changed, so the feed is not reloaded for nothing.
  Future<void> apply(FeedFilters filters) async {
    if (filters == state) return;
    state = filters;
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.feedFilters, jsonEncode(filters.toJson()));
  }
}

final feedFiltersProvider =
    NotifierProvider<FeedFiltersController, FeedFilters>(FeedFiltersController.new);
