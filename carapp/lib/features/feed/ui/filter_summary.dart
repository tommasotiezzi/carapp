import 'package:intl/intl.dart';

import '../../../core/geo/italian_capitals.dart';
import '../../../core/l10n/vehicle_labels.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../onboarding/ui/budget_label.dart';
import '../../search/data/catalog.dart';
import '../../search/data/query_parser.dart';
import '../data/feed_filters.dart';

final _thousands = NumberFormat.decimalPattern('it_IT');

/// One active filter as a removable chip.
class FilterChipData {
  const FilterChipData(this.label, this.remove);

  final String label;

  /// The filters without this chip.
  final FeedFilters Function(FeedFilters) remove;
}

/// "5–10k", "Fino a € 8.000", "Da € 5.000", "€ 5.000–12.000".
String priceLabel(AppLocalizations t, FeedFilters f) {
  final budget = f.budget;
  if (budget != null) return t.budgetLabel(budget);
  final min = f.priceMinCents, max = f.priceMaxCents;
  if (min != null && max != null) {
    return '${Formatters.price(min)}–${_thousands.format(max ~/ 100)}';
  }
  if (max != null) return t.priceUpTo(Formatters.price(max));
  if (min != null) return t.priceFrom(Formatters.price(min));
  return t.filterPrice;
}

/// "Entro 50 km da Siena" ("Distanza" when off).
String distanceLabelOf(AppLocalizations t, FeedFilters f) {
  if (!f.hasDistance) return t.filterDistance;
  final city = ItalianCapitals.byCode[f.nearProvince]?.name;
  return city == null ? t.distanceWithin(f.radiusKm!) : t.distanceWithinFrom(f.radiusKm!, city);
}

/// "Dal 2018", "Fino al 2018", "2018", "2015–2018".
String yearLabel(AppLocalizations t, FeedFilters f) {
  final min = f.yearMin, max = f.yearMax;
  if (min != null && max != null) return min == max ? '$min' : '$min–$max';
  if (min != null) return t.yearFrom('$min');
  if (max != null) return t.yearUntil('$max');
  return t.filterYear;
}

/// Active filters in a fixed order (category first, free words last).
/// [catalog] turns ids into names; without it, counts are shown.
List<FilterChipData> filterChips(AppLocalizations t, FeedFilters f, Catalog? catalog) {
  final chips = <FilterChipData>[];

  if (f.hasDistance) {
    chips.add(FilterChipData(distanceLabelOf(t, f), (x) => x.clear(FilterSection.distance)));
  }

  final category = switch (f.categoryId) {
    'car' => t.vehicleCar,
    'motorcycle' => t.vehicleMotorcycle,
    _ => null,
  };
  if (category != null) chips.add(FilterChipData(category, (x) => x.copyWith(categoryId: null)));

  final makeNames = [for (final id in f.makeIds) (id, catalog?.makeById[id]?.name)];
  if (makeNames.every((m) => m.$2 != null)) {
    // Same brand in two categories (Honda cars + motorcycles): one chip.
    final byName = <String, Set<String>>{};
    for (final (id, name) in makeNames) {
      byName.putIfAbsent(name!, () => {}).add(id);
    }
    for (final MapEntry(key: name, value: ids) in (byName.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key)))) {
      chips.add(FilterChipData(name, (x) => x.copyWith(makeIds: x.makeIds.difference(ids))));
    }
  } else if (f.makeIds.isNotEmpty) {
    chips.add(FilterChipData(t.filterBrandCount(f.makeIds.length), (x) => x.copyWith(makeIds: const {})));
  }

  final models = [for (final id in f.modelIds) catalog?.modelById[id]];
  if (models.every((m) => m != null)) {
    final byLabel = <String, Set<String>>{};
    for (final m in models) {
      byLabel.putIfAbsent(catalog!.modelLabel(m!), () => {}).add(m.id);
    }
    for (final MapEntry(key: label, value: ids) in (byLabel.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key)))) {
      chips.add(FilterChipData(label, (x) => x.copyWith(modelIds: x.modelIds.difference(ids))));
    }
  } else if (f.modelIds.isNotEmpty) {
    chips.add(FilterChipData(t.filterModelCount(f.modelIds.length), (x) => x.copyWith(modelIds: const {})));
  }

  if (f.hasPrice) chips.add(FilterChipData(priceLabel(t, f), (x) => x.clear(FilterSection.price)));
  if (f.hasYear) chips.add(FilterChipData(yearLabel(t, f), (x) => x.clear(FilterSection.year)));
  if (f.mileageMaxKm != null) {
    chips.add(FilterChipData(
      t.mileageMax(_thousands.format(f.mileageMaxKm)),
      (x) => x.copyWith(mileageMaxKm: null),
    ));
  }
  for (final fuel in FeedFilters.fuelOptions.where(f.fuelTypes.contains)) {
    chips.add(FilterChipData(
      t.fuelLabel(fuel),
      (x) => x.copyWith(fuelTypes: {...x.fuelTypes}..remove(fuel)),
    ));
  }
  if (f.transmission != null) {
    chips.add(FilterChipData(t.transmissionLabel(f.transmission), (x) => x.copyWith(transmission: null)));
  }
  if (f.noviceDriver) {
    chips.add(FilterChipData(t.filterNovice, (x) => x.copyWith(noviceDriver: false)));
  }
  if (f.province != null) {
    chips.add(FilterChipData(
      QueryParser.provinceNames[f.province] ?? f.province!,
      (x) => x.copyWith(province: null),
    ));
  }
  for (final w in f.textWords) {
    chips.add(FilterChipData(
      '“$w”',
      (x) => x.copyWith(textWords: [...x.textWords]..remove(w)),
    ));
  }
  return chips;
}

/// "Auto · Volkswagen · 5–10k · Dal 2018": saved search name and subtitle.
String describeFilters(AppLocalizations t, FeedFilters f, Catalog? catalog) {
  final labels = filterChips(t, f, catalog).map((c) => c.label).toList();
  return labels.isEmpty ? t.searchAllVehicles : labels.join(' · ');
}
