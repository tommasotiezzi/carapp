import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/vehicle_labels.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/pill.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../onboarding/data/buyer_preferences.dart';
import '../../onboarding/data/catalog_repository.dart';
import '../../onboarding/ui/budget_label.dart';
import '../data/feed_filters.dart';
import '../state/feed_filters_controller.dart';

/// Filter sheet over the feed. [only] = one pill's section; null = all.
/// Changes are a draft until "Mostra annunci", so the feed reloads once.
Future<void> showFilterSheet(BuildContext context, {FilterSection? only}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FilterSheet(only: only),
    );

String filterSectionTitle(AppLocalizations t, FilterSection s) => switch (s) {
      FilterSection.vehicle => t.prefsVehicle,
      FilterSection.price => t.filterPrice,
      FilterSection.brand => t.filterBrands,
      FilterSection.year => t.filterYear,
      FilterSection.mileage => t.prefsMileage,
      FilterSection.fuel => t.specFuel,
    };

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key, this.only});

  final FilterSection? only;

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  static final _thousands = NumberFormat.decimalPattern('it_IT');

  late FeedFilters _draft = ref.read(feedFiltersProvider);
  bool _allBrands = false;

  List<FilterSection> get _sections =>
      widget.only == null ? FilterSection.values : [widget.only!];

  void _update(FeedFilters Function(FeedFilters) f) => setState(() => _draft = f(_draft));

  void _reset() => _update((d) => widget.only == null ? FeedFilters.empty : d.clear(widget.only!));

  Future<void> _apply() async {
    await ref.read(feedFiltersProvider.notifier).apply(_draft);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final single = widget.only != null;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.s, AppSpacing.s),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    single ? filterSectionTitle(t, widget.only!) : t.filterTitle,
                    style: text.titleLarge,
                  ),
                ),
                TextButton(onPressed: _reset, child: Text(t.filterReset)),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in _sections) ...[
                    if (!single) SectionLabel(filterSectionTitle(t, s)),
                    _section(t, s),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.l),
            child: FilledButton(onPressed: _apply, child: Text(t.filterApply)),
          ),
        ],
      ),
    );
  }

  Widget _section(AppLocalizations t, FilterSection s) {
    final d = _draft;
    return switch (s) {
      FilterSection.vehicle => PillWrap(children: [
          for (final (id, label) in [
            (null, t.vehicleAll),
            ('car', t.vehicleCar),
            ('motorcycle', t.vehicleMotorcycle),
          ])
            Pill(
              label: label,
              selected: d.categoryId == id,
              // Brands belong to a category: reset them on change.
              onTap: () => _update((x) => x.categoryId == id
                  ? x
                  : x.copyWith(categoryId: id, makeIds: const {})),
            ),
        ]),
      FilterSection.price => PillWrap(children: [
          Pill(
            label: t.commonAny,
            selected: !d.hasPrice,
            onTap: () => _update((x) => x.clear(FilterSection.price)),
          ),
          for (final o in BudgetOption.values)
            Pill(
              label: t.budgetLabel(o),
              selected: d.budget == o,
              onTap: () => _update((x) => x.copyWith(priceMinCents: o.minCents, priceMaxCents: o.maxCents)),
            ),
        ]),
      FilterSection.brand => _brands(t),
      FilterSection.year => PillWrap(children: [
          Pill(
            label: t.commonAny,
            selected: d.yearMin == null,
            onTap: () => _update((x) => x.copyWith(yearMin: null)),
          ),
          for (final y in FeedFilters.yearOptions)
            Pill(
              label: t.yearFrom('$y'),
              selected: d.yearMin == y,
              onTap: () => _update((x) => x.copyWith(yearMin: y)),
            ),
        ]),
      FilterSection.mileage => PillWrap(children: [
          Pill(
            label: t.commonAny,
            selected: d.mileageMaxKm == null,
            onTap: () => _update((x) => x.copyWith(mileageMaxKm: null)),
          ),
          for (final km in FeedFilters.mileageOptions)
            Pill(
              label: t.mileageMax(_thousands.format(km)),
              selected: d.mileageMaxKm == km,
              onTap: () => _update((x) => x.copyWith(mileageMaxKm: km)),
            ),
        ]),
      FilterSection.fuel => PillWrap(children: [
          Pill(
            label: t.commonAll,
            selected: d.fuelTypes.isEmpty,
            onTap: () => _update((x) => x.copyWith(fuelTypes: const {})),
          ),
          for (final f in FeedFilters.fuelOptions)
            Pill(
              label: t.fuelLabel(f),
              selected: d.fuelTypes.contains(f),
              onTap: () => _update((x) => x.copyWith(
                    fuelTypes: x.fuelTypes.contains(f)
                        ? ({...x.fuelTypes}..remove(f))
                        : {...x.fuelTypes, f},
                  )),
            ),
        ]),
    };
  }

  /// Popular makes (plus the selected ones); "+ Altre" shows them all.
  Widget _brands(AppLocalizations t) {
    final makes = ref.watch(makesProvider(_draft.categoryId ?? 'car'));
    final selected = _draft.makeIds;

    void toggle(String id) => _update((x) => x.copyWith(
          makeIds: x.makeIds.contains(id) ? ({...x.makeIds}..remove(id)) : {...x.makeIds, id},
        ));

    return makes.when(
      loading: () => const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => ref.invalidate(makesProvider(_draft.categoryId ?? 'car')),
          child: Text(t.commonRetry),
        ),
      ),
      data: (all) {
        final shown = _allBrands
            ? ([...all]..sort((a, b) => a.name.compareTo(b.name)))
            : all.where((m) => m.isPopular || selected.contains(m.id)).toList();
        return PillWrap(children: [
          Pill(
            label: t.commonAll,
            selected: selected.isEmpty,
            onTap: () => _update((x) => x.copyWith(makeIds: const {})),
          ),
          for (final m in shown)
            Pill(label: m.name, selected: selected.contains(m.id), onTap: () => toggle(m.id)),
          if (!_allBrands && shown.length < all.length)
            Pill(
              label: t.moreBrands,
              selected: false,
              dashed: true,
              onTap: () => setState(() => _allBrands = true),
            ),
        ]);
      },
    );
  }
}
