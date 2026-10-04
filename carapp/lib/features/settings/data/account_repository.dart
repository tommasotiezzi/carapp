import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../auth/data/auth_repository.dart';

/// Mirrors the `gender` enum (optional, never asked in onboarding).
enum Gender {
  female('female'),
  male('male'),
  other('other'),
  undisclosed('undisclosed');

  const Gender(this.dbName);
  final String dbName;

  static Gender? fromDb(String? v) => Gender.values.where((g) => g.dbName == v).firstOrNull;
}

/// The optional parts of `profiles` editable in the settings.
class MyProfile {
  const MyProfile({this.displayName, this.birthDate, this.gender});

  final String? displayName;
  final DateTime? birthDate;
  final Gender? gender;

  static const minAge = 14;
  static const maxDisplayName = 60; // profiles.display_name check

  /// Latest birth date allowed: [minAge] years ago today.
  static DateTime latestBirthDate(DateTime today) =>
      DateTime(today.year - minAge, today.month, today.day);

  factory MyProfile.fromRow(Map<String, dynamic> row) => MyProfile(
        displayName: row['display_name'] as String?,
        birthDate: DateTime.tryParse((row['birth_date'] as String?) ?? ''),
        gender: Gender.fromDb(row['gender'] as String?),
      );
}

/// Notification types the user can switch off (`notification_type`).
/// A missing `notification_preferences` row means "on".
const buyerNotificationTypes = ['new_message', 'price_drop', 'listing_sold', 'saved_search_match'];
const sellerNotificationTypes = ['new_contact', 'listing_expiring'];

enum EmailChange { done, confirmationSent }

class AccountRepository {
  AccountRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Needs a signed-in user');
    return id;
  }

  Future<MyProfile> fetchProfile() async {
    final row = await _client
        .from('profiles')
        .select('display_name, birth_date, gender')
        .eq('id', _userId)
        .single();
    return MyProfile.fromRow(row);
  }

  /// [patch] uses `profiles` column names; null clears a value.
  Future<void> updateProfile(Map<String, dynamic> patch) =>
      _client.from('profiles').update(patch).eq('id', _userId);

  /// Signs in again with [password]: email, password changes and account
  /// deletion must come from someone who knows it, not from a phone left
  /// unlocked. Throws [AuthFailureException].
  Future<void> reauthenticate(String password) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw const AuthFailureException(AuthFailure.generic);
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      throw AuthFailureException(AuthRepository.failureOf(e));
    }
  }

  Future<EmailChange> changeEmail({required String password, required String newEmail}) async {
    await reauthenticate(password);
    final email = newEmail.trim().toLowerCase();
    try {
      final res = await _client.auth.updateUser(UserAttributes(email: email));
      // With "Secure email change" on, Supabase waits for the link.
      return res.user?.email == email ? EmailChange.done : EmailChange.confirmationSent;
    } catch (e) {
      throw AuthFailureException(AuthRepository.failureOf(e));
    }
  }

  Future<void> changePassword({required String current, required String next}) async {
    await reauthenticate(current);
    try {
      await _client.auth.updateUser(UserAttributes(password: next));
    } catch (e) {
      throw AuthFailureException(AuthRepository.failureOf(e));
    }
  }

  /// `delete-account` Edge Function, then local sign out (the user no
  /// longer exists on the server).
  Future<void> deleteAccount(String password) async {
    await reauthenticate(password);
    await _client.functions.invoke('delete-account');
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  Future<Map<String, bool>> fetchNotificationPrefs() async {
    final rows = await _client.from('notification_preferences').select('type, enabled');
    return {for (final r in rows) r['type'] as String: r['enabled'] as bool};
  }

  Future<void> setNotificationPref(String type, bool enabled) =>
      _client.from('notification_preferences').upsert(
        {'profile_id': _userId, 'type': type, 'enabled': enabled},
        onConflict: 'profile_id,type',
      );
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(supabaseProvider)),
);
