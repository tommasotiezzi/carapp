import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../feed/data/feed_filters.dart';

/// One row of `saved_searches`. [filters] is stored as the
/// `FeedFilters` JSON (same keys as the `listings` columns).
class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.filters,
    this.notify = true,
  });

  final String id;
  final String name;
  final FeedFilters filters;
  final bool notify;

  static const selectColumns = 'id, name, filters, notify';

  factory SavedSearch.fromRow(Map<String, dynamic> row) => SavedSearch(
        id: row['id'] as String,
        name: row['name'] as String,
        filters: FeedFilters.fromJson(
          Map<String, dynamic>.from((row['filters'] as Map?) ?? const {}),
        ),
        notify: (row['notify'] as bool?) ?? true,
      );

  SavedSearch copyWith({bool? notify}) =>
      SavedSearch(id: id, name: name, filters: filters, notify: notify ?? this.notify);
}

/// `saved_searches`; RLS limits every query to the signed-in user.
class SavedSearchRepository {
  SavedSearchRepository(this._client);

  final SupabaseClient _client;

  static const maxNameLength = 60;

  /// Alphabetical: the table has no documented creation timestamp.
  Future<List<SavedSearch>> fetchAll() async {
    final rows = await _client.from('saved_searches').select(SavedSearch.selectColumns).order('name');
    return rows.map(SavedSearch.fromRow).toList();
  }

  Future<SavedSearch> create({
    required String name,
    required FeedFilters filters,
    required bool notify,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Saved searches need a signed-in user');
    final row = await _client
        .from('saved_searches')
        .insert({
          'profile_id': userId,
          'name': name.trim(),
          'filters': filters.toJson(),
          'notify': notify,
        })
        .select(SavedSearch.selectColumns)
        .single();
    return SavedSearch.fromRow(row);
  }

  Future<void> setNotify(String id, bool notify) =>
      _client.from('saved_searches').update({'notify': notify}).eq('id', id);

  Future<void> delete(String id) => _client.from('saved_searches').delete().eq('id', id);
}

final savedSearchRepositoryProvider = Provider<SavedSearchRepository>(
  (ref) => SavedSearchRepository(ref.watch(supabaseProvider)),
);
