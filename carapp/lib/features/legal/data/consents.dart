import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/supabase/supabase_client.dart';

/// Mirrors the `consent_kind` enum.
enum ConsentKind {
  terms('terms'),
  privacy('privacy'),
  age14('age_14'),
  marketingEmail('marketing_email');

  const ConsentKind(this.dbName);
  final String dbName;

  static ConsentKind? fromDb(String? value) =>
      ConsentKind.values.where((k) => k.dbName == value).firstOrNull;
}

/// The latest decision for one kind (`current_consents` view).
class ConsentState {
  const ConsentState({required this.granted, this.version, this.at});

  final bool granted;
  final String? version;
  final DateTime? at;
}

/// Versions of the legal documents currently in force (app_config.legal).
class LegalVersions {
  const LegalVersions({this.terms, this.privacy});

  final String? terms;
  final String? privacy;

  factory LegalVersions.of(AppConfig config) => LegalVersions(
        terms: config.legalVersion('terms_version'),
        privacy: config.legalVersion('privacy_version'),
      );
}

/// True when the signed-in user must (re)accept before using the app:
/// terms, privacy and the age declaration are required; terms and privacy
/// again whenever their version changed. A null version (config without
/// versions) only requires that they were accepted once.
bool consentNeeded(Map<ConsentKind, ConsentState> current, LegalVersions versions) {
  bool ok(ConsentKind kind, String? version) {
    final c = current[kind];
    return c != null && c.granted && (version == null || c.version == version);
  }

  return !ok(ConsentKind.terms, versions.terms) ||
      !ok(ConsentKind.privacy, versions.privacy) ||
      !ok(ConsentKind.age14, null);
}

/// What the user ticked at sign up / in the consent sheet.
class ConsentChoices {
  const ConsentChoices({required this.marketingEmail});

  final bool marketingEmail;

  /// Rows for `user_consents`: the required ones are always granted here
  /// (the UI does not let the user continue otherwise).
  List<Map<String, dynamic>> rows(String profileId, LegalVersions versions) => [
        _row(profileId, ConsentKind.terms, true, versions.terms),
        _row(profileId, ConsentKind.privacy, true, versions.privacy),
        _row(profileId, ConsentKind.age14, true, null),
        _row(profileId, ConsentKind.marketingEmail, marketingEmail, null),
      ];
}

Map<String, dynamic> _row(String profileId, ConsentKind kind, bool granted, String? version) => {
      'profile_id': profileId,
      'kind': kind.dbName,
      'granted': granted,
      'document_version': version,
      'platform': switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        TargetPlatform.android => 'android',
        _ => 'web',
      },
    };

/// `user_consents` (append-only) and the `current_consents` view.
class ConsentRepository {
  ConsentRepository(this._client, this._prefs);

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Consents need a signed-in user');
    return id;
  }

  Future<Map<ConsentKind, ConsentState>> fetchCurrent() async {
    final rows = await _client
        .from('current_consents')
        .select('kind, granted, document_version, created_at');
    final current = <ConsentKind, ConsentState>{};
    for (final r in rows) {
      final kind = ConsentKind.fromDb(r['kind'] as String?);
      if (kind == null) continue; // a kind added later on the server
      current[kind] = ConsentState(
        granted: r['granted'] as bool,
        version: r['document_version'] as String?,
        at: DateTime.tryParse((r['created_at'] as String?) ?? ''),
      );
    }
    return current;
  }

  Future<void> record(ConsentChoices choices, LegalVersions versions) =>
      _client.from('user_consents').insert(choices.rows(_userId, versions));

  /// One optional consent changed from the settings.
  Future<void> set(ConsentKind kind, bool granted, {String? version}) =>
      _client.from('user_consents').insert(_row(_userId, kind, granted, version));

  // ---- sign up with email confirmation on: no session yet, so the
  // choices wait on the phone and are recorded at the first sign in ----

  Future<void> keepPending(String email, ConsentChoices choices, LegalVersions versions) =>
      _prefs.setString(
        PrefKeys.pendingConsents,
        jsonEncode({
          'email': email.trim().toLowerCase(),
          'marketing_email': choices.marketingEmail,
          'terms_version': versions.terms,
          'privacy_version': versions.privacy,
        }),
      );

  /// Records the pending choices if they belong to the signed-in user.
  Future<void> flushPending() async {
    final raw = _prefs.getString(PrefKeys.pendingConsents);
    final email = _client.auth.currentUser?.email?.toLowerCase();
    if (raw == null || email == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['email'] != email) return;
    await record(
      ConsentChoices(marketingEmail: json['marketing_email'] as bool? ?? false),
      LegalVersions(
        terms: json['terms_version'] as String?,
        privacy: json['privacy_version'] as String?,
      ),
    );
    await _prefs.remove(PrefKeys.pendingConsents);
  }
}

final consentRepositoryProvider = Provider<ConsentRepository>(
  (ref) => ConsentRepository(ref.watch(supabaseProvider), ref.watch(sharedPreferencesProvider)),
);
