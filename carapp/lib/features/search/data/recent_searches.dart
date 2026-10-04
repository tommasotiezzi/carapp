import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import 'catalog.dart';

/// Last searches typed on this phone (also for guests), newest first.
class RecentSearchesController extends Notifier<List<String>> {
  static const max = 10;

  @override
  List<String> build() =>
      ref.read(sharedPreferencesProvider).getStringList(PrefKeys.recentSearches) ?? const [];

  /// Moves [query] to the top; the same search typed differently
  /// ("Golf  Diesel" / "golf diesel") is kept once.
  Future<void> add(String query) async {
    final q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty) return;
    final key = Catalog.normalize(q);
    state = [q, ...state.where((s) => Catalog.normalize(s) != key)].take(max).toList();
    await _save();
  }

  Future<void> remove(String query) async {
    state = state.where((s) => s != query).toList();
    await _save();
  }

  Future<void> clear() async {
    state = const [];
    await _save();
  }

  Future<void> _save() =>
      ref.read(sharedPreferencesProvider).setStringList(PrefKeys.recentSearches, state);
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesController, List<String>>(RecentSearchesController.new);
