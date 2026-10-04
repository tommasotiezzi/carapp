import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';

class Make {
  const Make({
    required this.id,
    required this.name,
    required this.categoryId,
    this.isPopular = false,
  });

  final String id;
  final String name;
  final String categoryId; // 'car' | 'motorcycle'
  final bool isPopular;

  factory Make.fromRow(Map<String, dynamic> row) => Make(
        id: row['id'] as String,
        name: row['name'] as String,
        categoryId: row['category_id'] as String,
        isPopular: (row['is_popular'] as bool?) ?? false,
      );
}

/// Every make of every category: one request per app session, shared by
/// onboarding, the filter sheet and the Search catalog.
/// Popular ones first, then alphabetical.
final allMakesProvider = FutureProvider<List<Make>>((ref) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('makes')
      .select('id, name, category_id, is_popular')
      .order('is_popular', ascending: false)
      .order('name');
  return rows.map(Make.fromRow).toList();
});

/// Makes of one category ('car' / 'motorcycle'), from [allMakesProvider].
final makesProvider = FutureProvider.family<List<Make>, String>((ref, categoryId) async {
  final all = await ref.watch(allMakesProvider.future);
  return all.where((m) => m.categoryId == categoryId).toList();
});
