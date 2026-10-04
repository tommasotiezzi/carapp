import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/account_repository.dart';

/// Optional profile info; null for guests. Edits are optimistic.
class MyProfileController extends AsyncNotifier<MyProfile?> {
  @override
  Future<MyProfile?> build() async {
    if (ref.watch(currentUserIdProvider) == null) return null;
    return ref.read(accountRepositoryProvider).fetchProfile();
  }

  Future<void> edit(MyProfile next, Map<String, dynamic> patch) async {
    final before = state.value;
    state = AsyncData(next);
    try {
      await ref.read(accountRepositoryProvider).updateProfile(patch);
    } catch (_) {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }
}

final myProfileProvider =
    AsyncNotifierProvider<MyProfileController, MyProfile?>(MyProfileController.new);

/// The user's dealer (null if none). Edits are optimistic.
class MyDealerController extends AsyncNotifier<MyDealer?> {
  @override
  Future<MyDealer?> build() async {
    if (ref.watch(currentUserIdProvider) == null) return null;
    return ref.read(accountRepositoryProvider).fetchMyDealer();
  }

  /// Reload after a change made elsewhere (the picture).
  void refreshLocal() => ref.invalidateSelf();

  Future<void> edit(MyDealer next, Map<String, dynamic> patch) async {
    final before = state.value;
    state = AsyncData(next);
    try {
      await ref.read(accountRepositoryProvider).updateDealer(next.id, patch);
    } catch (_) {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }
}

final myDealerProvider = AsyncNotifierProvider<MyDealerController, MyDealer?>(MyDealerController.new);

/// Per-type notification switches; a missing type is on.
class NotificationPrefsController extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const {};
    return ref.read(accountRepositoryProvider).fetchNotificationPrefs();
  }

  bool isOn(String type) => state.value?[type] ?? true;

  Future<void> set(String type, bool enabled) async {
    final before = state.value ?? const <String, bool>{};
    state = AsyncData({...before, type: enabled});
    try {
      await ref.read(accountRepositoryProvider).setNotificationPref(type, enabled);
    } catch (_) {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }
}

final notificationPrefsProvider =
    AsyncNotifierProvider<NotificationPrefsController, Map<String, bool>>(
        NotificationPrefsController.new);
