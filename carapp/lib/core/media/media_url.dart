import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a storage path into a URL the player can load.
/// Full http(s) URLs pass through untouched (handy for test data).
class MediaUrl {
  MediaUrl._();

  static const publicBucket = 'listing-media';

  static String? resolve(SupabaseClient client, String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return client.storage.from(publicBucket).getPublicUrl(path);
  }
}
