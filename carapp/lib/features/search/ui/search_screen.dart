import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/ui/login_sheet.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../../feed/data/feed_filters.dart';
import '../../feed/state/feed_controller.dart';
import '../../feed/state/feed_filters_controller.dart';
import '../../feed/ui/filter_sheet.dart';
import '../../feed/ui/filter_summary.dart';
import '../../feed/ui/listing_card.dart';
import '../data/catalog.dart';
import '../data/query_parser.dart';
import '../data/recent_searches.dart';
import '../data/saved_search.dart';
import '../data/suggestions.dart';
import '../state/search_providers.dart';

/// "Cerca" tab. A search box understood locally (QueryParser), chips for
/// what was understood, results as a grid. Filters, results and the feed
/// pills are one shared state: the grid is the feed's own list, so
/// "Guarda nel feed" just switches tab.
///
/// No request while typing: suggestions come from the in-memory catalog;
/// the query is applied on submit or after a 400 ms pause.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static const typingPause = Duration(milliseconds: 400);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _pause;

  /// Filters produced by the text box. A filter change that is not this
  /// one (pills, chips, sheet, saved search) clears the box: the chips
  /// are the truth, the text was only the input.
  FeedFilters? _fromText;
  List<String> _ignored = const [];

  /// Typed before the catalog arrived: parsed again once it is there.
  String? _waitingForCatalog;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    ref.listenManual(feedFiltersProvider, (_, next) {
      if (next != _fromText && _ctrl.text.isNotEmpty) {
        _ctrl.clear();
        setState(() => _ignored = const []);
      }
    });
    ref.listenManual(catalogProvider, (_, next) {
      final pending = _waitingForCatalog;
      if (next.hasValue && pending != null) {
        _waitingForCatalog = null;
        _apply(pending);
      }
    });
  }

  @override
  void dispose() {
    _pause?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {}); // suggestions are computed in build, locally
    _pause?.cancel();
    _pause = Timer(SearchScreen.typingPause, () => _apply(text));
  }

  void _submit(String text) {
    _pause?.cancel();
    _focus.unfocus();
    _apply(text, remember: true);
  }

  /// Parses [text] and applies it to the shared filters.
  Future<void> _apply(String text, {bool remember = false}) async {
    final catalog = ref.read(catalogProvider);
    if (remember) await ref.read(recentSearchesProvider.notifier).add(text);
    if (!catalog.hasValue && catalog.isLoading && text.trim().isNotEmpty) {
      // Parsing without makes/models would search "golf" as free text:
      // wait for the catalog instead of sending a wrong request.
      _waitingForCatalog = text;
      return;
    }
    if (text.trim().isEmpty) {
      // Emptying the box removes what the box had added.
      if (_fromText != null && ref.read(feedFiltersProvider) == _fromText) {
        _fromText = FeedFilters.empty;
        await ref.read(feedFiltersProvider.notifier).apply(FeedFilters.empty);
      }
      if (mounted) setState(() => _ignored = const []);
      return;
    }
    final parsed = QueryParser(
      catalog.value ?? Catalog.empty,
      homeProvince: ref.read(homeProvinceProvider),
    ).parse(text);
    _fromText = parsed.filters;
    if (mounted) setState(() => _ignored = parsed.ignored);
    await ref.read(feedFiltersProvider.notifier).apply(parsed.filters);
  }

  /// Fills the box and searches right away (recents, suggestions, brands).
  void _search(String text) {
    _ctrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _submit(text);
  }

  Future<void> _rememberTyped() async {
    if (_ctrl.text.trim().isNotEmpty) {
      await ref.read(recentSearchesProvider.notifier).add(_ctrl.text);
    }
  }

  Future<void> _applyFilters(FeedFilters filters) =>
      ref.read(feedFiltersProvider.notifier).apply(filters);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final filters = ref.watch(feedFiltersProvider);
    final catalog = ref.watch(catalogProvider).value;
    final chips = filterChips(t, filters, catalog);
    final suggestions =
        _focus.hasFocus && catalog != null ? suggest(_ctrl.text, catalog) : const <SearchSuggestion>[];
    final idle = filters.isEmpty && _ctrl.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.m, AppSpacing.page, 0),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  onChanged: _onChanged,
                  onSubmitted: _submit,
                  decoration: InputDecoration(
                    hintText: t.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _ctrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: t.searchClear,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _ctrl.clear();
                              _onChanged('');
                            },
                          ),
                  ),
                ),
              ),
            ),
            if (suggestions.isNotEmpty)
              SliverList.list(children: [
                for (final s in suggestions)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      s.isModel ? Icons.directions_car_outlined : Icons.sell_outlined,
                      color: AppColors.inkMuted,
                    ),
                    title: Text(s.label, style: text.bodyLarge),
                    onTap: () => _search(s.query.trim()),
                  ),
              ]),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.m, AppSpacing.page, 0),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.tune, size: 18),
                      label: Text(
                        filters.isEmpty ? t.filterTitle : '${t.filterTitle} · ${filters.activeCount}',
                      ),
                      onPressed: () => showFilterSheet(context),
                    ),
                    for (final c in chips)
                      InputChip(
                        label: Text(c.label),
                        onDeleted: () => _applyFilters(c.remove(filters)),
                        deleteButtonTooltipMessage: t.searchRemoveChip(c.label),
                      ),
                  ],
                ),
              ),
            ),
            if (_ignored.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s, AppSpacing.page, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(t.searchIgnored(_ignored.join(', ')), style: text.bodySmall),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.l, AppSpacing.page, AppSpacing.xxl),
              sliver: SliverToBoxAdapter(
                child: idle
                    ? _Home(onSearch: _search, catalog: catalog)
                    : _Results(chips: chips, filters: filters, onOpen: _rememberTyped),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: filters.isEmpty
          ? null
          : _ActionBar(filters: filters, onShowInFeed: _rememberTyped),
    );
  }
}

/// Before typing: recent searches, saved searches, popular brands.
class _Home extends ConsumerWidget {
  const _Home({required this.onSearch, required this.catalog});

  final ValueChanged<String> onSearch;
  final Catalog? catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final recents = ref.watch(recentSearchesProvider);
    final saved = ref.watch(savedSearchesProvider).value ?? const <SavedSearch>[];
    final popular = <String>{
      for (final m in catalog?.makes ?? const <CatalogMake>[])
        if (m.isPopular && m.categoryId == 'car') m.name,
    }.toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recents.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text(t.searchRecent, style: text.titleLarge)),
              TextButton(
                onPressed: () => ref.read(recentSearchesProvider.notifier).clear(),
                child: Text(t.searchClearRecent),
              ),
            ],
          ),
          for (final q in recents)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.history, color: AppColors.inkMuted),
              title: Text(q, style: text.bodyLarge),
              trailing: IconButton(
                tooltip: t.searchRemoveChip(q),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => ref.read(recentSearchesProvider.notifier).remove(q),
              ),
              onTap: () => onSearch(q),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (saved.isNotEmpty) ...[
          Text(t.searchSavedTitle, style: text.titleLarge),
          const SizedBox(height: AppSpacing.m),
          for (final s in saved) ...[
            _SavedSearchTile(search: s, catalog: catalog),
            const SizedBox(height: AppSpacing.s),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
        if (popular.isNotEmpty) ...[
          Text(t.searchPopularBrands, style: text.titleLarge),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              for (final name in popular) ActionChip(label: Text(name), onPressed: () => onSearch(name)),
            ],
          ),
        ],
      ],
    );
  }
}

/// The feed's own list as a grid; tap opens the listing.
class _Results extends ConsumerWidget {
  const _Results({required this.chips, required this.filters, required this.onOpen});

  final List<FilterChipData> chips;
  final FeedFilters filters;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final results = ref.watch(feedControllerProvider);
    final state = results.value;

    if (state == null) {
      if (results.hasError) {
        return Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => ref.read(feedControllerProvider.notifier).refresh(),
            child: Text(t.commonRetry),
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 2,
          child: results.isLoading ? const LinearProgressIndicator(minHeight: 2) : null,
        ),
        const SizedBox(height: AppSpacing.s),
        if (state.items.isEmpty)
          _NoResults(chips: chips, filters: filters)
        else
          ListingCardGrid(children: [
            for (final item in state.items) ListingCard(item: item, onOpen: onOpen),
          ]),
        if (state.hasMore && state.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.l),
          OutlinedButton(
            onPressed: state.isLoadingMore
                ? null
                : () => ref.read(feedControllerProvider.notifier).loadMore(),
            child: state.isLoadingMore
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t.searchLoadMore),
          ),
        ],
        if (state.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s),
          Text(t.searchTapHint, style: text.bodySmall, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

/// Zero results: drop the last chip, or save the search and wait.
class _NoResults extends ConsumerWidget {
  const _NoResults({required this.chips, required this.filters});

  final List<FilterChipData> chips;
  final FeedFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final last = chips.isEmpty ? null : chips.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.l),
        Text(t.searchZeroTitle, style: text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.l),
        if (last != null)
          FilledButton(
            onPressed: () => ref.read(feedFiltersProvider.notifier).apply(last.remove(filters)),
            child: Text(t.searchTryWithout(last.label), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        const SizedBox(height: AppSpacing.s),
        OutlinedButton.icon(
          onPressed: () => saveSearch(context, ref, filters),
          icon: const Icon(Icons.notifications_active_outlined, size: 20),
          label: Text(t.searchSaveAndNotify, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// "Salva ricerca": guests sign in first (like Save); the name is
/// pre-filled with the chips ("Auto · Golf · Diesel").
Future<void> saveSearch(BuildContext context, WidgetRef ref, FeedFilters filters) async {
  final t = AppLocalizations.of(context);
  if (ref.read(currentUserProvider) == null) {
    final ok = await showLoginSheet(context, title: t.searchLoginTitle, subtitle: t.searchLoginSubtitle);
    if (!ok || !context.mounted) return;
  }
  final name = describeFilters(t, filters, ref.read(catalogProvider).value);
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SaveSearchSheet(
      filters: filters,
      defaultName: name.length > SavedSearchRepository.maxNameLength
          ? name.substring(0, SavedSearchRepository.maxNameLength)
          : name,
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.searchSavedDone)));
  }
}

/// Sticky "Salva ricerca" + "Guarda nel feed" (same results, as videos).
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.filters, required this.onShowInFeed});

  final FeedFilters filters;
  final Future<void> Function() onShowInFeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.m, AppSpacing.page, AppSpacing.m),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => saveSearch(context, ref, filters),
                child: Text(t.searchSave, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  await onShowInFeed();
                  if (context.mounted) context.go(AppRoutes.feed);
                },
                child: Text(t.searchShowInFeed, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Name (pre-filled) and, once push exists, the alert switch.
class _SaveSearchSheet extends ConsumerStatefulWidget {
  const _SaveSearchSheet({required this.filters, required this.defaultName});

  final FeedFilters filters;
  final String defaultName;

  @override
  ConsumerState<_SaveSearchSheet> createState() => _SaveSearchSheetState();
}

class _SaveSearchSheetState extends ConsumerState<_SaveSearchSheet> {
  late final _nameCtrl = TextEditingController(text: widget.defaultName);
  bool _notify = true; // `saved_searches.notify` default
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(savedSearchesProvider.notifier).create(
            name: _nameCtrl.text,
            filters: widget.filters,
            notify: _notify,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = t.searchError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final config = ref.watch(appConfigProvider).value ?? AppConfig.empty;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.searchSave, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.l),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            maxLength: SavedSearchRepository.maxNameLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: t.searchNameLabel),
            onChanged: (_) => setState(() {}),
          ),
          if (config.flag('push_enabled'))
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
              title: Text(t.searchNotify, style: text.bodyLarge),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.m),
          FilledButton(
            onPressed: _busy || _nameCtrl.text.trim().isEmpty ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(t.searchSave),
          ),
        ],
      ),
    );
  }
}

/// Tap applies the saved filters (chips and results update in place).
class _SavedSearchTile extends ConsumerWidget {
  const _SavedSearchTile({required this.search, required this.catalog});

  final SavedSearch search;
  final Catalog? catalog;

  Future<void> _run(BuildContext context, Future<void> Function() action, {String? done}) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.searchError)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final controller = ref.read(savedSearchesProvider.notifier);
    final config = ref.watch(appConfigProvider).value ?? AppConfig.empty;

    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: () => ref.read(feedFiltersProvider.notifier).apply(search.filters),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.xxs, AppSpacing.s),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(search.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      describeFilters(t, search.filters, catalog),
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (config.flag('push_enabled'))
                IconButton(
                  tooltip: search.notify ? t.searchNotifyOn : t.searchNotifyOff,
                  icon: Icon(
                    search.notify ? Icons.notifications_active : Icons.notifications_off_outlined,
                    color: search.notify ? AppColors.primary : AppColors.inkMuted,
                  ),
                  onPressed: () => _run(context, () => controller.setNotify(search.id, !search.notify)),
                ),
              PopupMenuButton<void>(
                tooltip: t.searchMore,
                itemBuilder: (_) => [
                  PopupMenuItem<void>(
                    onTap: () => _run(context, () => controller.delete(search.id), done: t.searchDeleted),
                    child: Text(t.searchDelete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
