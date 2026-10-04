import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import 'feed_filters.dart';
import 'feed_item.dart';

/// Reads active listings, newest first, one page at a time.
/// Cursor pagination on published_at: no offsets, no counting.
/// Filters map 1:1 to `listings` columns (all indexed for active rows).
class FeedRepository {
  FeedRepository(this._client);

  final SupabaseClient _client;

  Future<List<FeedItem>> fetchPage({
    DateTime? before,
    int pageSize = 10,
    FeedFilters filters = FeedFilters.empty,
  }) async {
    var query = _client
        .from('listings')
        .select(FeedItem.selectColumns)
        .eq('status', 'active');

    final f = filters;
    if (f.categoryId != null) query = query.eq('category_id', f.categoryId!);
    if (f.priceMinCents != null) query = query.gte('price_cents', f.priceMinCents!);
    if (f.priceMaxCents != null) query = query.lte('price_cents', f.priceMaxCents!);
    if (f.makeIds.isNotEmpty) query = query.inFilter('make_id', f.makeIds.toList());
    if (f.modelIds.isNotEmpty) query = query.inFilter('model_id', f.modelIds.toList());
    if (f.yearMin != null) query = query.gte('year', f.yearMin!);
    if (f.yearMax != null) query = query.lte('year', f.yearMax!);
    if (f.mileageMaxKm != null) query = query.lte('mileage_km', f.mileageMaxKm!);
    if (f.fuelTypes.isNotEmpty) query = query.inFilter('fuel_type', f.fuelTypes.toList());
    if (f.transmission != null) query = query.eq('transmission', f.transmission!);
    if (f.province != null) query = query.eq('province', f.province!);
    final logic = logicFilter(f);
    if (logic != null) query = query.or(logic);

    if (before != null) {
      query = query.lt('published_at', before.toUtc().toIso8601String());
    }

    final rows = await query
        .order('published_at', ascending: false)
        .limit(pageSize);

    return rows.map(FeedItem.fromRow).toList();
  }
}

/// The conditions PostgREST can only express with `or`, merged into a
/// single `or=(and(...))` (one `or` parameter per request):
/// - each free word must appear in version or description;
/// - novice drivers: cars up to [FeedFilters.noviceMaxPowerKw] kW,
///   other categories untouched.
/// null when there is nothing to add.
String? logicFilter(FeedFilters f) {
  final groups = <String>[
    for (final w in f.textWords.map(_likeSafe).where((w) => w.isNotEmpty))
      'or(version.ilike.*$w*,description.ilike.*$w*)',
    if (f.noviceDriver)
      f.categoryId == 'car'
          ? 'power_kw.lte.${FeedFilters.noviceMaxPowerKw}'
          : 'or(category_id.neq.car,power_kw.lte.${FeedFilters.noviceMaxPowerKw})',
  ];
  return groups.isEmpty ? null : 'and(${groups.join(',')})';
}

/// Letters and digits only: commas, dots, parentheses or wildcards would
/// break (or widen) the PostgREST filter.
String _likeSafe(String word) =>
    word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9àèéìòù]'), '');

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(ref.watch(supabaseProvider)),
);
