import 'package:intl/intl.dart';

import '../../../core/l10n/vehicle_labels.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../onboarding/data/catalog_repository.dart';
import '../../onboarding/ui/budget_label.dart';
import '../data/feed_filters.dart';

final _thousands = NumberFormat.decimalPattern('it_IT');

/// "Auto · Volkswagen, Fiat · 5–10k · Dal 2018": default name and
/// subtitle of a saved search. [makes] resolves make ids to names.
String describeFilters(AppLocalizations t, FeedFilters f, List<Make> makes) {
  final makeNames = [
    for (final id in f.makeIds) makes.where((m) => m.id == id).firstOrNull?.name,
  ].whereType<String>().toList()
    ..sort();
  final budget = f.budget;

  final parts = [
    switch (f.categoryId) {
      'car' => t.vehicleCar,
      'motorcycle' => t.vehicleMotorcycle,
      _ => null,
    },
    if (makeNames.isNotEmpty)
      makeNames.length <= 2
          ? makeNames.join(', ')
          : '${makeNames.take(2).join(', ')} +${makeNames.length - 2}'
    else if (f.makeIds.isNotEmpty)
      t.filterBrandCount(f.makeIds.length),
    if (budget != null) t.budgetLabel(budget),
    if (f.yearMin != null) t.yearFrom('${f.yearMin}'),
    if (f.mileageMaxKm != null) t.mileageMax(_thousands.format(f.mileageMaxKm)),
    for (final fuel in f.fuelTypes) t.fuelLabel(fuel),
  ].whereType<String>().where((s) => s.isNotEmpty);

  return parts.isEmpty ? t.searchAllVehicles : parts.join(' · ');
}
