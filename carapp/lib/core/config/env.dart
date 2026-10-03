/// Build-time configuration, passed with --dart-define or --dart-define-from-file.
/// Nothing secret lives in the repository.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Custom scheme used for deep links until the web domain exists,
  /// e.g. carfeed://app/listing/<id>
  static const deepLinkScheme = String.fromEnvironment(
    'DEEP_LINK_SCHEME',
    defaultValue: 'carfeed',
  );

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL / SUPABASE_ANON_KEY. '
        'Run with --dart-define-from-file=env.json',
      );
    }
  }
}
