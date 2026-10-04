import 'dart:typed_data';

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
  const MyProfile({
    this.displayName,
    this.birthDate,
    this.gender,
    this.province,
    this.phone,
    this.phonePublic = false,
    this.whatsappPublic = false,
    this.avatarPath,
  });

  final String? displayName;
  final DateTime? birthDate;
  final Gender? gender;

  /// Public profile: capital, and the contacts the user chose to show.
  final String? province;
  final String? phone;
  final bool phonePublic;
  final bool whatsappPublic;

  /// Profile picture in the `avatars` bucket.
  final String? avatarPath;

  static const _unset = Object();

  MyProfile copyWith({
    Object? displayName = _unset,
    Object? birthDate = _unset,
    Object? gender = _unset,
    Object? province = _unset,
    Object? phone = _unset,
    bool? phonePublic,
    bool? whatsappPublic,
    Object? avatarPath = _unset,
  }) =>
      MyProfile(
        displayName: identical(displayName, _unset) ? this.displayName : displayName as String?,
        birthDate: identical(birthDate, _unset) ? this.birthDate : birthDate as DateTime?,
        gender: identical(gender, _unset) ? this.gender : gender as Gender?,
        province: identical(province, _unset) ? this.province : province as String?,
        phone: identical(phone, _unset) ? this.phone : phone as String?,
        phonePublic: phonePublic ?? this.phonePublic,
        whatsappPublic: whatsappPublic ?? this.whatsappPublic,
        avatarPath: identical(avatarPath, _unset) ? this.avatarPath : avatarPath as String?,
      );

  static const minAge = 14;
  static const maxDisplayName = 60; // profiles.display_name check

  /// Latest birth date allowed: [minAge] years ago today.
  static DateTime latestBirthDate(DateTime today) =>
      DateTime(today.year - minAge, today.month, today.day);

  factory MyProfile.fromRow(Map<String, dynamic> row) => MyProfile(
        displayName: row['display_name'] as String?,
        birthDate: DateTime.tryParse((row['birth_date'] as String?) ?? ''),
        gender: Gender.fromDb(row['gender'] as String?),
        province: row['province'] as String?,
        phone: row['phone'] as String?,
        phonePublic: (row['phone_public'] as bool?) ?? false,
        whatsappPublic: (row['whatsapp_public'] as bool?) ?? false,
        avatarPath: row['avatar_path'] as String?,
      );
}

/// The dealer the user belongs to, with what its page shows. Only an
/// owner may edit it (RLS `dealers_update_owner`).
class MyDealer {
  const MyDealer({
    required this.id,
    required this.isOwner,
    this.displayName,
    this.description,
    this.phone,
    this.whatsapp,
    this.website,
    this.city,
    this.province,
  });

  final String id;
  final bool isOwner;
  final String? displayName;
  final String? description;
  final String? phone;
  final String? whatsapp;
  final String? website;
  final String? city;
  final String? province;

  static const columns = 'id, display_name, description, phone, whatsapp, website, city, province';

  /// The same dealer with one `dealers` column changed.
  MyDealer copyWith(String column, String? value) => MyDealer(
        id: id,
        isOwner: isOwner,
        displayName: column == 'display_name' ? value : displayName,
        description: column == 'description' ? value : description,
        phone: column == 'phone' ? value : phone,
        whatsapp: column == 'whatsapp' ? value : whatsapp,
        website: column == 'website' ? value : website,
        city: column == 'city' ? value : city,
        province: column == 'province' ? value : province,
      );

  factory MyDealer.fromRow(Map<String, dynamic> row, {required bool isOwner}) => MyDealer(
        id: row['id'] as String,
        isOwner: isOwner,
        displayName: row['display_name'] as String?,
        description: row['description'] as String?,
        phone: row['phone'] as String?,
        whatsapp: row['whatsapp'] as String?,
        website: row['website'] as String?,
        city: row['city'] as String?,
        province: row['province'] as String?,
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
        .select('display_name, birth_date, gender, province, phone, phone_public, whatsapp_public, avatar_path')
        .eq('id', _userId)
        .single();
    return MyProfile.fromRow(row);
  }

  /// [patch] uses `profiles` column names; null clears a value.
  Future<void> updateProfile(Map<String, dynamic> patch) =>
      _client.from('profiles').update(patch).eq('id', _userId);

  /// null when the user is not part of a dealer.
  Future<MyDealer?> fetchMyDealer() async {
    final membership = await _client
        .from('dealer_members')
        .select('dealer_id, role')
        .eq('profile_id', _userId)
        .limit(1)
        .maybeSingle();
    if (membership == null) return null;
    final row = await _client
        .from('dealers')
        .select(MyDealer.columns)
        .eq('id', membership['dealer_id'] as String)
        .single();
    return MyDealer.fromRow(row, isOwner: membership['role'] == 'owner');
  }

  /// [patch] uses `dealers` column names (public data only: the VIES
  /// fields are locked by the database).
  Future<void> updateDealer(String dealerId, Map<String, dynamic> patch) =>
      _client.from('dealers').update(patch).eq('id', dealerId);

  static const avatarsBucket = 'avatars';

  /// Uploads a JPEG picture to `avatars/<user>/<uuid>.jpg`; returns its path.
  Future<String> uploadAvatar(Uint8List bytes, String fileName) async {
    final path = '$_userId/$fileName';
    await _client.storage.from(avatarsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return path;
  }

  /// Best effort: an old picture left behind is only wasted space.
  Future<void> removeAvatar(String path) async {
    if (!path.startsWith('$_userId/')) return;
    try {
      await _client.storage.from(avatarsBucket).remove([path]);
    } catch (_) {}
  }

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
