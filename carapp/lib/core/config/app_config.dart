import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/preferences.dart';
import '../supabase/supabase_client.dart';

/// Snapshot of the public rows of the `app_config` table.
class AppConfig {
  const AppConfig({required this.version, required this.values});

  final int version;
  final Map<String, dynamic> values;

  static const empty = AppConfig(version: 0, values: {});

  factory AppConfig.fromRows(List<Map<String, dynamic>> rows) {
    final values = {for (final r in rows) r['key'] as String: r['value']};
    return AppConfig(
      version: (values['config_version'] as num?)?.toInt() ?? 0,
      values: values,
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        version: (json['version'] as num).toInt(),
        values: Map<String, dynamic>.from(json['values'] as Map),
      );

  Map<String, dynamic> toJson() => {'version': version, 'values': values};

  Map<String, dynamic> _section(String key) =>
      Map<String, dynamic>.from((values[key] as Map?) ?? const {});

  // ---- typed accessors -----------------------------------------------

  bool flag(String name) => (_section('feature_flags')[name] as bool?) ?? false;

  int onboardingValue(String name, int fallback) =>
      (_section('onboarding')[name] as num?)?.toInt() ?? fallback;

  int feedValue(String name, int fallback) =>
      (_section('feed')[name] as num?)?.toInt() ?? fallback;

  int mediaValue(String name, int fallback) =>
      (_section('media')[name] as num?)?.toInt() ?? fallback;

  /// e.g. minAppVersion('android') -> '1.0.0'
  String? minAppVersion(String platform) =>
      (_section('app_versions')[platform] as Map?)?['min'] as String?;

  String? latestAppVersion(String platform) =>
      (_section('app_versions')[platform] as Map?)?['latest'] as String?;

  String? legalUrl(String name) => _section('legal')[name] as String?;
}

class AppConfigRepository {
  AppConfigRepository(this._client, this._prefs);

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  AppConfig? readCache() {
    final raw = _prefs.getString(PrefKeys.appConfigCache);
    if (raw == null) return null;
    try {
      return AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// One tiny request to compare versions; the full config is downloaded
  /// only when `config_version` changed. Offline: last cached copy.
  Future<AppConfig> load() async {
    final cached = readCache();
    try {
      final row = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'config_version')
          .maybeSingle();
      final remoteVersion = (row?['value'] as num?)?.toInt() ?? 0;

      if (cached != null && cached.version == remoteVersion) return cached;

      final rows = await _client.from('app_config').select('key, value');
      final fresh = AppConfig.fromRows(rows);
      await _prefs.setString(
        PrefKeys.appConfigCache,
        jsonEncode(fresh.toJson()),
      );
      return fresh;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
  }
}

final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (ref) => AppConfigRepository(
    ref.watch(supabaseProvider),
    ref.watch(sharedPreferencesProvider),
  ),
);

/// Loaded once per app launch. Screens read it with
/// `ref.watch(appConfigProvider).value ?? AppConfig.empty`.
final appConfigProvider = FutureProvider<AppConfig>(
  (ref) => ref.watch(appConfigRepositoryProvider).load(),
);
