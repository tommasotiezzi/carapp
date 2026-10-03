import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/pill.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/buyer_preferences.dart';
import '../data/catalog_repository.dart';
import '../state/onboarding_controller.dart';
import 'onboarding_exit.dart';

/// "Cosa cerchi?" Used in onboarding and, with [editing], from the profile.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key, this.editing = false});

  /// true = opened from the profile: save and go back instead of finishing onboarding.
  final bool editing;

  static final _thousands = NumberFormat.decimalPattern('it_IT');

  Future<void> _finish(BuildContext context, WidgetRef ref, {required bool keep}) async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    if (editing) {
      await controller.savePreferences();
      if (context.mounted) context.pop();
      return;
    }
    await controller.complete(keepPreferences: keep);
    if (context.mounted) exitOnboarding(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final p = ref.watch(onboardingControllerProvider.select((s) => s.preferences));
    final controller = ref.read(onboardingControllerProvider.notifier);
    void update(BuyerPreferences Function(BuyerPreferences) f) => controller.updatePreferences(f);

    String budgetLabel(BudgetOption o) => switch (o) {
          BudgetOption.upTo5k => t.budgetUpTo('5k'),
          BudgetOption.from5to10k => '5–10k',
          BudgetOption.from10to15k => '10–15k',
          BudgetOption.from15to25k => '15–25k',
          BudgetOption.over25k => t.budgetOver('25k'),
        };

    final brandCategory = p.categoryId ?? 'car';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  if (!editing)
                    TextButton(
                      onPressed: () => _finish(context, ref, keep: false),
                      child: Text(t.commonSkip),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.s, AppSpacing.xl, AppSpacing.xl),
                children: [
                  Text(t.prefsTitle, style: text.headlineMedium),
                  const SizedBox(height: AppSpacing.s),
                  Text(t.prefsSubtitle, style: text.bodyMedium),
                  const SizedBox(height: AppSpacing.xxl),

                  SectionLabel(t.prefsVehicle),
                  PillWrap(children: [
                    for (final (id, label) in [
                      (null, t.vehicleAll),
                      ('car', t.vehicleCar),
                      ('motorcycle', t.vehicleMotorcycle),
                    ])
                      Pill(
                        label: label,
                        selected: p.categoryId == id,
                        // Brands depend on the category: reset them on change.
                        onTap: () => update((x) => x.copyWith(categoryId: id, makeIds: const [])),
                      ),
                  ]),
                  const SizedBox(height: AppSpacing.xxl),

                  SectionLabel(t.prefsBudget),
                  PillWrap(children: [
                    Pill(
                      label: t.commonAny,
                      selected: p.budget == null,
                      onTap: () => update((x) => x.copyWith(budget: null)),
                    ),
                    for (final o in BudgetOption.values)
                      Pill(
                        label: budgetLabel(o),
                        selected: p.budget == o,
                        onTap: () => update((x) => x.copyWith(budget: o)),
                      ),
                  ]),
                  const SizedBox(height: AppSpacing.xxl),

                  SectionLabel(t.prefsBrands),
                  _BrandPills(categoryId: brandCategory),
                  const SizedBox(height: AppSpacing.xxl),

                  SectionLabel(t.prefsYear),
                  PillWrap(children: [
                    Pill(
                      label: t.commonAny,
                      selected: p.yearMin == null,
                      onTap: () => update((x) => x.copyWith(yearMin: null)),
                    ),
                    for (final y in BuyerPreferences.yearOptions)
                      Pill(
                        label: t.yearFrom('$y'),
                        selected: p.yearMin == y,
                        onTap: () => update((x) => x.copyWith(yearMin: y)),
                      ),
                  ]),
                  const SizedBox(height: AppSpacing.xxl),

                  SectionLabel(t.prefsMileage),
                  PillWrap(children: [
                    Pill(
                      label: t.commonAny,
                      selected: p.mileageMaxKm == null,
                      onTap: () => update((x) => x.copyWith(mileageMaxKm: null)),
                    ),
                    for (final km in BuyerPreferences.mileageOptions)
                      Pill(
                        label: t.mileageMax(_thousands.format(km)),
                        selected: p.mileageMaxKm == km,
                        onTap: () => update((x) => x.copyWith(mileageMaxKm: km)),
                      ),
                  ]),
                  const SizedBox(height: AppSpacing.xxl),

                  Material(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.l),
                    child: SwitchListTile(
                      value: p.noviceDriver,
                      onChanged: (v) => update((x) => x.copyWith(noviceDriver: v)),
                      title: Text(t.prefsNovice, style: text.titleSmall),
                      subtitle: Text(t.prefsNoviceSubtitle, style: text.bodySmall),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.s, AppSpacing.xl, AppSpacing.l),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: () => _finish(context, ref, keep: true),
                    child: Text(editing ? t.prefsSaveCta : t.prefsCta),
                  ),
                  if (!editing) ...[
                    const SizedBox(height: AppSpacing.s),
                    Text(t.prefsFootnote, style: text.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Tutte" + popular makes + "+ Altre" (sheet with every make).
class _BrandPills extends ConsumerWidget {
  const _BrandPills({required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final makes = ref.watch(makesProvider(categoryId));
    final selected = ref.watch(onboardingControllerProvider.select((s) => s.preferences.makeIds));
    final controller = ref.read(onboardingControllerProvider.notifier);

    void toggle(String id) => controller.updatePreferences((p) {
          final ids = [...p.makeIds];
          ids.contains(id) ? ids.remove(id) : ids.add(id);
          return p.copyWith(makeIds: ids);
        });

    return makes.when(
      loading: () => const SizedBox(
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => TextButton(
        onPressed: () => ref.invalidate(makesProvider(categoryId)),
        child: Text(t.commonRetry),
      ),
      data: (all) {
        final popular = all.where((m) => m.isPopular).toList();
        // Selected makes that are not popular still show as pills.
        final extra = all.where((m) => !m.isPopular && selected.contains(m.id));
        return PillWrap(children: [
          Pill(
            label: t.commonAll,
            selected: selected.isEmpty,
            onTap: () => controller.updatePreferences((p) => p.copyWith(makeIds: const [])),
          ),
          for (final m in [...popular, ...extra])
            Pill(label: m.name, selected: selected.contains(m.id), onTap: () => toggle(m.id)),
          Pill(
            label: t.moreBrands,
            selected: false,
            dashed: true,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => _AllBrandsSheet(makes: all, onToggle: toggle),
            ),
          ),
        ]);
      },
    );
  }
}

class _AllBrandsSheet extends ConsumerWidget {
  const _AllBrandsSheet({required this.makes, required this.onToggle});

  final List<Make> makes;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final selected = ref.watch(onboardingControllerProvider.select((s) => s.preferences.makeIds));
    final sorted = [...makes]..sort((a, b) => a.name.compareTo(b.name));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.s, AppSpacing.s),
            child: Row(
              children: [
                Expanded(
                  child: Text(t.brandsSheetTitle, style: Theme.of(context).textTheme.titleLarge),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: Text(t.commonDone)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: sorted.length,
              itemBuilder: (_, i) => CheckboxListTile(
                value: selected.contains(sorted[i].id),
                onChanged: (_) => onToggle(sorted[i].id),
                title: Text(sorted[i].name),
                activeColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}