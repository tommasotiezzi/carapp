import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';

class Make {
  const Make({required this.id, required this.name, required this.isPopular});

  final String id;
  final String name;
  final bool isPopular;

  factory Make.fromRow(Map<String, dynamic> row) => Make(
        id: row['id'] as String,
        name: row['name'] as String,
        isPopular: (row['is_popular'] as bool?) ?? false,
      );
}

/// All makes of a category ('car' / 'motorcycle'), loaded once per session.
/// Popular ones first, then alphabetical.
final makesProvider = FutureProvider.family<List<Make>, String>((ref, categoryId) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('makes')
      .select('id, name, is_popular')
      .eq('category_id', categoryId)
      .order('is_popular', ascending: false)
      .order('name');
  return rows.map(Make.fromRow).toList();
});