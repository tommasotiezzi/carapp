import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a storage path into a URL the player can load.
/// Full http(s) URLs pass through untouched (handy for test data).
class MediaUrl {
  MediaUrl._();

  static const publicBucket = 'listing-media';

  static const avatarsBucket = 'avatars';

  /// Profile pictures (users and dealers).
  static String? avatar(SupabaseClient client, String? path) {
    if (path == null || path.isEmpty) return null;
    return client.storage.from(avatarsBucket).getPublicUrl(path);
  }

  static String? resolve(SupabaseClient client, String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return client.storage.from(publicBucket).getPublicUrl(path);
  }
}
