import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import 'feed_filters.dart';
import 'feed_item.dart';

/// Reads active listings, newest first, one page at a time.
/// Cursor pagination on (published_at, id): no offsets, no counting, and
/// no listing skipped when several share the same published_at (seeds,
/// bulk imports).
/// Filters map 1:1 to `listings` columns (all indexed for active rows).
class FeedRepository {
  FeedRepository(this._client);

  final SupabaseClient _client;

  /// [seller] narrows to one seller's listings (profile pages).
  Future<List<FeedItem>> fetchPage({
    FeedItem? after,
    int pageSize = 10,
    FeedFilters filters = FeedFilters.empty,
    SellerRef? seller,
  }) async {
    final f = filters;
    // "Entro X km": the provinces whose capital is in range.
    final provinces = f.provincesInRange;
    if (provinces != null && provinces.isEmpty) return const [];

    var query = _client
        .from('listings')
        .select(FeedItem.selectColumns)
        .eq('status', 'active');

    if (seller != null) {
      query = seller.isDealer
          ? query.eq('dealer_id', seller.id)
          : query.eq('owner_id', seller.id).eq('seller_type', 'private');
    }
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
    if (provinces != null) {
      query = query.inFilter('province', provinces.toList()..sort());
    } else if (f.province != null) {
      query = query.eq('province', f.province!);
    }
    final logic = logicFilter(f, after: after);
    if (logic != null) query = query.or(logic);

    final rows = await query
        .order('published_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);

    return rows.map(FeedItem.fromRow).toList();
  }
}

/// The conditions PostgREST can only express with `or`, merged into a
/// single `or=(and(...))` (one `or` parameter per request):
/// - each free word must appear in version or description;
/// - novice drivers: cars the seller marked "ok neopatentati"
///   (`attributes.novice_ok`, see vehicle_categories.attributes_schema);
///   when the seller said nothing, cars up to [FeedFilters.noviceMaxPowerKw]
///   kW; other categories untouched;
/// - the page cursor: strictly after [after] in (published_at, id) order.
/// null when there is nothing to add.
String? logicFilter(FeedFilters f, {FeedItem? after}) {
  final groups = <String>[
    for (final w in f.textWords.map(_likeSafe).where((w) => w.isNotEmpty))
      'or(version.ilike.*$w*,description.ilike.*$w*)',
    if (f.noviceDriver)
      f.categoryId == 'car' ? 'or($_noviceCar)' : 'or(category_id.neq.car,$_noviceCar)',
    if (after != null) _cursor(after),
  ];
  return groups.isEmpty ? null : 'and(${groups.join(',')})';
}

const _noviceCar = 'attributes->>novice_ok.eq.true,'
    'and(attributes->>novice_ok.is.null,power_kw.lte.${FeedFilters.noviceMaxPowerKw})';

/// Timestamps are quoted: ':' and '.' are reserved in PostgREST trees.
String _cursor(FeedItem after) {
  final ts = '"${after.publishedAt.toUtc().toIso8601String()}"';
  return 'or(published_at.lt.$ts,and(published_at.eq.$ts,id.lt.${after.id}))';
}

/// Letters and digits only: commas, dots, parentheses or wildcards would
/// break (or widen) the PostgREST filter.
String _likeSafe(String word) =>
    word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9àèéìòù]'), '');

/// A seller page: a dealer (`dealers.id`) or a private seller (`profiles.id`).
class SellerRef {
  const SellerRef.dealer(this.id) : isDealer = true;
  const SellerRef.private(this.id) : isDealer = false;

  final String id;
  final bool isDealer;

  @override
  bool operator ==(Object other) => other is SellerRef && other.id == id && other.isDealer == isDealer;

  @override
  int get hashCode => Object.hash(id, isDealer);
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(ref.watch(supabaseProvider)),
);
