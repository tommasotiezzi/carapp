import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../onboarding/data/catalog_repository.dart';

class CatalogMake {
  const CatalogMake({
    required this.id,
    required this.name,
    required this.categoryId,
    this.isPopular = false,
  });

  final String id;
  final String name;
  final String categoryId;
  final bool isPopular;
}

class CatalogModel {
  const CatalogModel({required this.id, required this.makeId, required this.name});

  final String id;
  final String makeId;
  final String name;
}

/// Every make and model, both categories, loaded once per app session.
/// Search suggestions and query parsing run on it locally: typing never
/// sends a request.
class Catalog {
  Catalog({required List<CatalogMake> makes, required List<CatalogModel> models})
      : makes = List.unmodifiable(makes),
        models = List.unmodifiable(models),
        makeById = {for (final m in makes) m.id: m},
        modelById = {for (final m in models) m.id: m};

  final List<CatalogMake> makes;
  final List<CatalogModel> models;
  final Map<String, CatalogMake> makeById;
  final Map<String, CatalogModel> modelById;

  static final empty = Catalog(makes: const [], models: const []);

  /// "Volkswagen Golf"
  String modelLabel(CatalogModel model) {
    final make = makeById[model.makeId];
    return make == null ? model.name : '${make.name} ${model.name}';
  }

  String? categoryOfModel(String modelId) =>
      makeById[modelById[modelId]?.makeId]?.categoryId;

  // ---- normalized indexes, built on first use ----

  /// (make, normalized name), for prefix search on every keystroke.
  late final List<(CatalogMake, String)> normalizedMakes = [
    for (final m in makes) (m, normalize(m.name)),
  ];

  /// (model, normalized name).
  late final List<(CatalogModel, String)> normalizedModels = [
    for (final m in models) (m, normalize(m.name)),
  ];

  /// normalized name or alias -> makes ("honda" exists for cars and motorcycles).
  late final Map<String, List<CatalogMake>> makesByKey = () {
    final map = <String, List<CatalogMake>>{};
    void add(String key, CatalogMake m) {
      if (key.isEmpty) return;
      final list = map.putIfAbsent(key, () => []);
      if (!list.contains(m)) list.add(m);
    }

    for (final m in makes) {
      add(normalize(m.name), m);
    }
    // First word as alias when it is long enough and points to one brand
    // ("alfa" -> Alfa Romeo, "mercedes" -> Mercedes-Benz).
    final byFirstWord = <String, Set<String>>{};
    for (final m in makes) {
      final words = normalize(m.name).split(' ');
      if (words.length > 1 && words.first.length >= 4) {
        byFirstWord.putIfAbsent(words.first, () => {}).add(normalize(m.name));
      }
    }
    for (final m in makes) {
      final words = normalize(m.name).split(' ');
      if (words.length > 1 && (byFirstWord[words.first]?.length ?? 0) == 1) {
        add(words.first, m);
      }
    }
    for (final MapEntry(key: alias, value: target) in _makeAliases.entries) {
      for (final m in makes.where((m) => normalize(m.name) == target)) {
        add(alias, m);
      }
    }
    return map;
  }();

  /// normalized model name -> models.
  late final Map<String, List<CatalogModel>> modelsByKey = () {
    final map = <String, List<CatalogModel>>{};
    for (final m in models) {
      map.putIfAbsent(normalize(m.name), () => []).add(m);
    }
    return map;
  }();

  static const _makeAliases = {'vw': 'volkswagen', 'merc': 'mercedes benz'};

  /// Lowercase, no accents, punctuation as spaces: "Mercedes-Benz" ->
  /// "mercedes benz", "L'Aquila" -> "l aquila". Digits and dots in
  /// numbers are kept ("100.000").
  static String normalize(String s) {
    var out = s.toLowerCase();
    const accents = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    accents.forEach((from, to) => out = out.replaceAll(from, to));
    out = out.replaceAll('€', ' € ');
    // Keep "100.000" / "8,5k" together; other punctuation splits words.
    out = out.replaceAllMapped(RegExp(r'(?<!\d)[.,]|[.,](?!\d)'), (_) => ' ');
    out = out.replaceAll(RegExp(r"[^a-z0-9.,€\s]"), ' ');
    return out.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
  }
}

class CatalogRepository {
  CatalogRepository(this._client);

  final SupabaseClient _client;

  /// PostgREST returns at most 1000 rows per request (Supabase default).
  static const _page = 1000;

  /// [allMakes] comes from `allMakesProvider` (already loaded by
  /// onboarding or the filter sheet): only the models are fetched here.
  Future<Catalog> load(List<Make> allMakes) async {
    final makes = [
      for (final m in allMakes)
        CatalogMake(id: m.id, name: m.name, categoryId: m.categoryId, isPopular: m.isPopular),
    ];

    final models = <CatalogModel>[];
    for (var from = 0;; from += _page) {
      final rows = await _client
          .from('models')
          .select('id, make_id, name')
          .order('id')
          .range(from, from + _page - 1);
      models.addAll([
        for (final r in rows)
          CatalogModel(
            id: r['id'] as String,
            makeId: r['make_id'] as String,
            name: r['name'] as String,
          ),
      ]);
      if (rows.length < _page) break;
    }
    return Catalog(makes: makes, models: models);
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(supabaseProvider)),
);

/// Kept for the whole session (not auto-disposed).
final catalogProvider = FutureProvider<Catalog>((ref) async {
  final makes = await ref.watch(allMakesProvider.future);
  return ref.watch(catalogRepositoryProvider).load(makes);
});
