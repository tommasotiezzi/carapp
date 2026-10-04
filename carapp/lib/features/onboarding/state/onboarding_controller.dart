import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/geo/italian_capitals.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/buyer_preferences.dart';

class OnboardingState {
  const OnboardingState({
    this.intent,
    this.preferences = const BuyerPreferences(),
    this.done = false,
  });

  final UserIntent? intent;
  final BuyerPreferences preferences;
  final bool done;

  OnboardingState copyWith({
    UserIntent? intent,
    BuyerPreferences? preferences,
    bool? done,
  }) =>
      OnboardingState(
        intent: intent ?? this.intent,
        preferences: preferences ?? this.preferences,
        done: done ?? this.done,
      );
}

/// Holds the onboarding choices. Saved on the phone first (works for guests),
/// pushed to Supabase as soon as the user has an account.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(PrefKeys.buyerPreferences);
    BuyerPreferences preferences = const BuyerPreferences();
    if (raw != null) {
      try {
        preferences = BuyerPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return OnboardingState(
      intent: UserIntent.fromName(prefs.getString(PrefKeys.userIntent)),
      preferences: preferences,
      done: prefs.getBool(PrefKeys.onboardingDone) ?? false,
    );
  }

  void setIntent(UserIntent intent) => state = state.copyWith(intent: intent);

  void updatePreferences(BuyerPreferences Function(BuyerPreferences) update) =>
      state = state.copyWith(preferences: update(state.preferences));

  /// Saves everything and marks onboarding as done.
  /// [keepPreferences] false = the user tapped "Salta" on preferences.
  Future<void> complete({bool keepPreferences = true}) async {
    if (!keepPreferences) {
      state = state.copyWith(preferences: const BuyerPreferences());
    }
    state = state.copyWith(done: true);
    await _saveLocally();
    await syncIfLoggedIn();
  }

  /// "Salta" on the first screen: no intent, no preferences.
  Future<void> skip() async {
    state = state.copyWith(done: true);
    await _saveLocally();
  }

  /// Saves edited preferences (from the profile) without touching the rest.
  Future<void> savePreferences() async {
    await _saveLocally();
    await syncIfLoggedIn();
  }

  Future<void> _saveLocally() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefKeys.onboardingDone, state.done);
    await prefs.setString(PrefKeys.buyerPreferences, jsonEncode(state.preferences.toJson()));
    final intent = state.intent;
    if (intent != null) await prefs.setString(PrefKeys.userIntent, intent.dbName);
  }

  /// Called after onboarding and right after login.
  Future<void> syncIfLoggedIn() async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final province = state.preferences.province;
      final profileUpdate = <String, dynamic>{
        if (state.intent != null) 'intent': state.intent!.dbName,
        // The capital is also the city shown on the public profile.
        'province': ?province,
        if (province != null) 'city': ItalianCapitals.byCode[province]?.name,
        if (state.done) 'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (profileUpdate.isNotEmpty) {
        await client.from('profiles').update(profileUpdate).eq('id', userId);
      }
      if (!state.preferences.isEmpty) {
        await client.from('buyer_preferences').upsert(state.preferences.toRow(userId));
      }
    } catch (e) {
      // Local copy stays; the next login retries.
      if (kDebugMode) debugPrint('Onboarding sync failed: $e');
    }
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(OnboardingController.new);

/// The user's capital ("Dove sei?"), null if not chosen. Distances in
/// cards and "vicino a me" start from here.
final homeProvinceProvider = Provider<String?>(
  (ref) => ref.watch(onboardingControllerProvider.select((s) => s.preferences.province)),
);
