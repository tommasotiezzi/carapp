import '../../l10n/gen/app_localizations.dart';

/// Labels for database enum values (`fuel_type`, `transmission_type`).
extension VehicleLabels on AppLocalizations {
  String fuelLabel(String? dbValue) => switch (dbValue) {
        'petrol' => fuelPetrol,
        'diesel' => fuelDiesel,
        'hybrid' => fuelHybrid,
        'plugin_hybrid' => fuelPluginHybrid,
        'electric' => fuelElectric,
        'lpg' => fuelLpg,
        'cng' => fuelCng,
        'other' => fuelOther,
        _ => '',
      };

  String transmissionLabel(String? dbValue) => switch (dbValue) {
        'manual' => transmissionManual,
        'automatic' => transmissionAutomatic,
        'semi_automatic' => transmissionSemiAutomatic,
        _ => '',
      };
}
