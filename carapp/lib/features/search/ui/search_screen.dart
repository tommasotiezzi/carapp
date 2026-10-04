import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/ui/login_sheet.dart';
import '../../feed/data/feed_filters.dart';
import '../../feed/state/feed_filters_controller.dart';
import '../../feed/ui/filter_sheet.dart';
import '../../feed/ui/filter_summary.dart';
import '../../feed/ui/listing_card.dart';
import '../../onboarding/data/catalog_repository.dart';
import '../data/saved_search.dart';
import '../state/search_providers.dart';

/// "Cerca" tab: saved searches, every filter on one page, a results grid
/// that follows the filters, and "Guarda nel feed" to watch them as videos.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final draft = ref.watch(searchDraftProvider);
    final drafts = ref.read(searchDraftProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.l, AppSpacing.s, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(child: Text(t.navSearch, style: text.headlineMedium)),
                    if (!draft.isEmpty)
                      TextButton(
                        onPressed: () => drafts.update(FeedFilters.empty),
                        child: Text(t.filterReset),
                      ),
                  ],
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.l, AppSpacing.page, 0),
              sliver: SliverToBoxAdapter(child: _SavedSearches()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.l, AppSpacing.page, 0),
              sliver: SliverToBoxAdapter(
                child: FilterSections(filters: draft, onChanged: drafts.update),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.searchResults, style: text.titleLarge),
                    const SizedBox(height: AppSpacing.m),
                    const _Results(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ActionBar(draft: draft),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final results = ref.watch(searchResultsProvider);

    final state = results.value;

    // First load: spinner. Later reloads keep the previous grid with a thin
    // progress bar, so tapping pills does not make the results flicker.
    if (state == null) {
      if (results.hasError) {
        return Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => ref.invalidate(searchResultsProvider),
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
          Text(t.searchNoResults, style: Theme.of(context).textTheme.bodyMedium)
        else
          ListingCardGrid(children: [for (final item in state.items) ListingCard(item: item)]),
        if (state.hasMore && state.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.l),
          OutlinedButton(
            onPressed: state.isLoadingMore
                ? null
                : () => ref.read(searchResultsProvider.notifier).loadMore(),
            child: state.isLoadingMore
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t.searchLoadMore),
          ),
        ],
      ],
    );
  }
}

/// Sticky "Salva ricerca" + "Guarda nel feed".
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.draft});

  final FeedFilters draft;

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    if (ref.read(currentUserProvider) == null) {
      final ok = await showLoginSheet(
        context,
        title: t.searchLoginTitle,
        subtitle: t.searchLoginSubtitle,
      );
      if (!ok || !context.mounted) return;
    }

    List<Make> makes;
    try {
      makes = await ref.read(makesProvider(draft.categoryId ?? 'car').future);
    } catch (_) {
      makes = const [];
    }
    if (!context.mounted) return;

    final name = describeFilters(t, draft, makes);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SaveSearchSheet(
        filters: draft,
        defaultName: name.length > SavedSearchRepository.maxNameLength
            ? name.substring(0, SavedSearchRepository.maxNameLength)
            : name,
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.searchSavedDone)));
    }
  }

  Future<void> _showInFeed(BuildContext context, WidgetRef ref) async {
    await ref.read(feedFiltersProvider.notifier).apply(draft);
    if (context.mounted) context.go(AppRoutes.feed);
  }

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
                onPressed: () => _save(context, ref),
                child: Text(t.searchSave, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: FilledButton(
                onPressed: () => _showInFeed(context, ref),
                child: Text(t.searchShowInFeed, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Name (pre-filled with the filter summary) and, once push exists,
/// the alert switch.
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

/// Saved searches: tap opens them in the feed. Hidden when there are none.
class _SavedSearches extends ConsumerWidget {
  const _SavedSearches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final searches = ref.watch(savedSearchesProvider).value ?? const [];
    if (searches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.searchSavedTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.m),
        for (final s in searches) ...[
          _SavedSearchTile(search: s),
          const SizedBox(height: AppSpacing.s),
        ],
        const SizedBox(height: AppSpacing.m),
        const Divider(color: AppColors.border),
      ],
    );
  }
}

class _SavedSearchTile extends ConsumerWidget {
  const _SavedSearchTile({required this.search});

  final SavedSearch search;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action,
      {String? done}) async {
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
    final makes = ref.watch(makesProvider(search.filters.categoryId ?? 'car')).value ?? const [];
    final config = ref.watch(appConfigProvider).value ?? AppConfig.empty;

    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: () async {
          await ref.read(feedFiltersProvider.notifier).apply(search.filters);
          if (context.mounted) context.go(AppRoutes.feed);
        },
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
                      describeFilters(t, search.filters, makes),
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
                  onPressed: () =>
                      _run(context, ref, () => controller.setNotify(search.id, !search.notify)),
                ),
              PopupMenuButton<void>(
                tooltip: t.searchMore,
                itemBuilder: (_) => [
                  PopupMenuItem<void>(
                    onTap: () => _run(
                      context,
                      ref,
                      () => controller.delete(search.id),
                      done: t.searchDeleted,
                    ),
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
