import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import 'feed_item.dart';

/// Reads active listings, newest first, one page at a time.
/// Cursor pagination on published_at: no offsets, no counting.
class FeedRepository {
  FeedRepository(this._client);

  final SupabaseClient _client;

  Future<List<FeedItem>> fetchPage({DateTime? before, int pageSize = 10}) async {
    var query = _client
        .from('listings')
        .select(FeedItem.selectColumns)
        .eq('status', 'active');

    if (before != null) {
      query = query.lt('published_at', before.toUtc().toIso8601String());
    }

    final rows = await query
        .order('published_at', ascending: false)
        .limit(pageSize);

    return rows.map(FeedItem.fromRow).toList();
  }
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(ref.watch(supabaseProvider)),
);
