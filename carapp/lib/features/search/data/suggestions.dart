import 'catalog.dart';

/// A make or model the user is probably typing.
class SearchSuggestion {
  const SearchSuggestion({required this.label, required this.query, this.isModel = false});

  /// "Volkswagen Golf"
  final String label;

  /// The whole query with the word being typed completed.
  final String query;

  final bool isModel;
}

/// Completes the word being typed against the in-memory catalog.
/// Pure and synchronous: called on every keystroke, never hits the network.
List<SearchSuggestion> suggest(String text, Catalog catalog, {int limit = 6}) {
  if (text.isEmpty || text.endsWith(' ')) return const [];
  final words = Catalog.normalize(text).split(' ');
  final partial = words.last;
  if (partial.length < 2) return const [];
  final pair = words.length >= 2 ? '${words[words.length - 2]} $partial' : null;

  // Keep what was typed before the word being completed.
  final rawWords = text.trimRight().split(RegExp(r'\s+'));
  String complete(String label, {bool replacesPair = false}) {
    final keep = rawWords.take(rawWords.length - (replacesPair ? 2 : 1)).join(' ');
    return keep.isEmpty ? '$label ' : '$keep $label ';
  }

  // A make already typed narrows the models ("volkswagen go" -> Golf).
  final typedMakes = <String>{
    for (final w in words.take(words.length - 1))
      ...?catalog.makesByKey[w]?.map((m) => m.id),
  };

  final out = <SearchSuggestion>[];
  final seen = <String>{};
  void add(SearchSuggestion s) {
    if (out.length < limit && seen.add(s.label.toLowerCase())) out.add(s);
  }

  int byPopularity(CatalogMake a, CatalogMake b) => a.isPopular == b.isPopular
      ? a.name.length.compareTo(b.name.length)
      : (a.isPopular ? -1 : 1);

  // A two-word make being typed ("alfa ro" -> Alfa Romeo): its first word
  // also matches as an alias, so check the pair before anything else.
  if (pair != null) {
    final pairMakes = [
      for (final (m, key) in catalog.normalizedMakes)
        if (key.startsWith(pair)) m,
    ]..sort(byPopularity);
    for (final m in pairMakes) {
      add(SearchSuggestion(label: m.name, query: complete(m.name, replacesPair: true)));
    }
    if (pairMakes.isNotEmpty) return out;
  }

  if (typedMakes.isEmpty) {
    final makes = [
      for (final (m, key) in catalog.normalizedMakes)
        if (key.startsWith(partial)) m,
    ]..sort(byPopularity);
    for (final m in makes) {
      add(SearchSuggestion(label: m.name, query: complete(m.name)));
    }
  }

  // Without a make, 1-2 characters are too vague to suggest models.
  final models = typedMakes.isEmpty && partial.length < 3
      ? <(CatalogModel, String)>[]
      : [
          for (final (m, key) in catalog.normalizedModels)
            if ((typedMakes.isEmpty || typedMakes.contains(m.makeId)) &&
                (key.startsWith(partial) || (pair != null && key.startsWith(pair))))
              (m, key),
        ]
    ..sort((a, b) => a.$1.name.length.compareTo(b.$1.name.length));
  for (final (m, key) in models) {
    final replacesPair = pair != null && key.startsWith(pair) && !key.startsWith(partial);
    // With the make already typed, complete just the model name.
    add(SearchSuggestion(
      label: catalog.modelLabel(m),
      query: typedMakes.isEmpty
          ? complete(catalog.modelLabel(m), replacesPair: replacesPair)
          : complete(m.name, replacesPair: replacesPair),
      isModel: true,
    ));
  }
  return out;
}
